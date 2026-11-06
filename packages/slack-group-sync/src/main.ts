/**
 * Keeps authentik's researchers, students and staff groups equal to the Slack
 * user groups of the same role.
 *
 * Every reconcile reads both sides whole and applies the difference, so
 * events are only a hint to reconcile sooner: one runs after each Socket Mode
 * connect (Slack does not redeliver what it sent while no connection was
 * open), shortly after a relevant event, and at fixed times of day as a
 * safety net.
 *
 *   slack-group-sync              run as a service
 *   slack-group-sync --once       reconcile once and exit
 *     --dry-run                   print the plan, change nothing
 *     --force                     apply a removal above the safety limit
 */

import { createServer } from "node:http";
import { parseArgs } from "node:util";

import { SocketModeClient } from "@slack/socket-mode";
import { WebClient } from "@slack/web-api";
import { z } from "zod";

import { Authentik } from "./authentik.ts";
import { type Config, loadConfig } from "./config.ts";
import { type Action, plan } from "./plan.ts";
import { untilNext } from "./schedule.ts";
import { readSlack } from "./slack.ts";

/** Events that can change who belongs where. */
const relevant = new Set([
  "subteam_members_changed",
  "subteam_updated",
  "subteam_created",
  "user_change",
  "team_join",
]);

const retryMinMs = 30_000;
const retryMaxMs = 30 * 60_000;

function log(message: string): void {
  console.log(message);
}

function describe(action: Action): string {
  const who = `${action.user.name} (${action.user.pk})`;
  return action.group ? `${action.kind} ${who} ${action.group}` : `${action.kind} ${who}`;
}

interface Outcome {
  readonly ok: boolean;
  readonly reason?: string;
}

async function reconcile(
  config: Config,
  slack: WebClient,
  authentik: Authentik,
  options: { dryRun: boolean; force: boolean },
): Promise<Outcome> {
  const managed = [...Object.values(config.mapping.groups), config.mapping.pending];
  const [slackState, authentikState] = await Promise.all([
    readSlack(slack),
    authentik.read(config.sourceSlug, managed),
  ]);
  const result = plan(slackState, authentikState, config.mapping, { force: options.force });
  for (const warning of result.warnings) {
    log(`warning: ${warning}`);
  }
  if (result.halt) {
    log(`halted: ${result.halt}`);
    return { ok: false, reason: result.halt };
  }
  for (const action of result.actions) {
    log(`${options.dryRun ? "would " : ""}${describe(action)}`);
    if (!options.dryRun) {
      await authentik.apply(action);
    }
  }
  log(`reconciled: ${result.actions.length} change(s)`);
  const untrusted = result.warnings.find((w) => w.includes("not an admin"));
  return untrusted ? { ok: false, reason: untrusted } : { ok: true };
}

const envelope = z.object({
  ack: z.custom<() => Promise<void>>((value) => typeof value === "function"),
  body: z.looseObject({ event: z.looseObject({ type: z.string() }).optional() }).optional(),
});

async function serve(config: Config, slack: WebClient, authentik: Authentik): Promise<void> {
  let lastSuccess = 0;
  let problem: string | undefined = "no reconcile yet";
  const connected = new Set<number>();

  // One reconcile at a time; requests that arrive meanwhile collapse into one
  // more run after it.
  let timer: NodeJS.Timeout | undefined;
  let running = false;
  let again = false;
  // A failed reconcile is retried with backoff instead of waiting for the next
  // event or scheduled time; Authentik answers 503 while it restarts.
  let retryMs = retryMinMs;
  let retry: NodeJS.Timeout | undefined;
  const run = async (reason: string) => {
    if (running) {
      again = true;
      return;
    }
    running = true;
    try {
      log(`reconcile: ${reason}`);
      const outcome = await reconcile(config, slack, authentik, { dryRun: false, force: false });
      if (outcome.ok) {
        lastSuccess = Date.now();
        problem = undefined;
      } else {
        problem = outcome.reason;
      }
    } catch (error) {
      problem = String(error instanceof Error ? error.message : error);
      log(`reconcile failed: ${problem}`);
    } finally {
      clearTimeout(retry);
      if (problem === undefined) {
        retryMs = retryMinMs;
      } else {
        log(`retrying in ${Math.round(retryMs / 1000)} s`);
        retry = setTimeout(() => void run("retry"), retryMs);
        retryMs = Math.min(retryMs * 2, retryMaxMs);
      }
      running = false;
      if (again) {
        again = false;
        void run("requested while running");
      }
    }
  };
  const soon = (reason: string) => {
    clearTimeout(timer);
    timer = setTimeout(() => void run(reason), config.debounceMs);
  };

  const scheduleNext = () => {
    setTimeout(() => {
      void run("scheduled");
      scheduleNext();
    }, untilNext(config.times, config.timezone));
  };
  scheduleNext();

  const clients = Array.from({ length: config.connections }, (_, index) => {
    const client = new SocketModeClient({ appToken: config.slackAppToken });
    client.on("slack_event", (args: unknown) => {
      const parsed = envelope.safeParse(args);
      if (!parsed.success) {
        return;
      }
      void parsed.data.ack();
      const type = parsed.data.body?.event?.type;
      if (type && relevant.has(type)) {
        soon(`event ${type}`);
      }
    });
    client.on("connected", () => {
      connected.add(index);
      soon("connected");
    });
    client.on("disconnected", () => connected.delete(index));
    client.on("reconnecting", () => connected.delete(index));
    client.on("error", (error: unknown) => log(`socket ${index} error: ${String(error)}`));
    return client;
  });

  const health = createServer((request, response) => {
    if (request.url !== "/healthz") {
      response.writeHead(404).end();
      return;
    }
    const reasons = [
      problem,
      connected.size === 0 ? "no Socket Mode connection" : undefined,
      Date.now() - lastSuccess > config.maxQuietMs ? "no successful reconcile recently" : undefined,
    ].filter((reason) => reason !== undefined);
    response
      .writeHead(reasons.length === 0 ? 200 : 503, { "Content-Type": "application/json" })
      .end(JSON.stringify({ ok: reasons.length === 0, reasons, lastSuccess, connections: connected.size }));
  });
  health.listen(config.healthPort, "127.0.0.1");

  await Promise.all(clients.map((client) => client.start()));
  log(`listening with ${clients.length} Socket Mode connection(s)`);

  const stop = () => {
    health.close();
    void Promise.allSettled(clients.map((client) => client.disconnect())).then(() => process.exit(0));
  };
  process.once("SIGTERM", stop);
  process.once("SIGINT", stop);
}

async function main(): Promise<void> {
  const { values } = parseArgs({
    options: {
      once: { type: "boolean", default: false },
      "dry-run": { type: "boolean", default: false },
      force: { type: "boolean", default: false },
    },
  });
  const config = loadConfig();
  const slack = new WebClient(config.slackBotToken);
  const authentik = new Authentik(config.authentikUrl, config.authentikToken);
  if (values.once || values["dry-run"]) {
    const outcome = await reconcile(config, slack, authentik, {
      dryRun: values["dry-run"],
      force: values.force,
    });
    process.exitCode = outcome.ok ? 0 : 1;
    return;
  }
  await serve(config, slack, authentik);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
