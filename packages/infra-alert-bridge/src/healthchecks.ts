import { processAlert } from "./alertmanager";
import { HttpError } from "./alertmanager";
import type { CanonicalAlert, Env } from "./types";

interface HealthchecksPayload {
  uuid?: string;
  name?: string;
  status?: string;
  code?: string | number;
  event?: string;
  desc?: string;
}

export async function handleHealthchecks(request: Request, env: Env, now: number): Promise<Response> {
  assertBearer(request, env.HEALTHCHECKS_WEBHOOK_TOKEN);
  const payload = await parsePayload(request);
  const alert = canonicalize(payload, env, now);
  await processAlert(env, alert, now);
  return json({ ok: true, fingerprint: alert.fingerprint, status: alert.status });
}

function canonicalize(payload: HealthchecksPayload, env: Env, now: number): CanonicalAlert {
  const name = payload.name ?? "rho-alertmanager-watchdog";
  const uuid = payload.uuid ?? name;
  const statusText = String(payload.status ?? payload.event ?? payload.code ?? "down").toLowerCase();
  const resolved = ["up", "success", "ok", "0", "200"].includes(statusText);
  const status = resolved ? "resolved" : "firing";
  const summary =
    status === "firing" ? `${name} missed expected pings` : `${name} resumed expected pings`;
  const description = payload.desc ?? "healthchecks.io dead-man notification";

  return {
    fingerprint: `healthchecks:${uuid}`,
    source: "healthchecks",
    receiver: "infra-alerts",
    status,
    severity: "critical",
    alertname: "HealthchecksDeadman",
    summary,
    description,
    labels: {
      alertname: "HealthchecksDeadman",
      severity: "critical",
      service: name,
      source: "healthchecks.io",
    },
    annotations: { summary, description },
    startsAt: new Date(now * 1000).toISOString(),
    endsAt: status === "resolved" ? new Date(now * 1000).toISOString() : "",
    channelId: env.SLACK_INFRA_ALERTS_CHANNEL_ID,
  };
}

async function parsePayload(request: Request): Promise<HealthchecksPayload> {
  const contentType = request.headers.get("Content-Type") ?? "";
  if (contentType.includes("application/json")) {
    return (await request.json()) as HealthchecksPayload;
  }

  const text = await request.text();
  if (!text) return {};

  try {
    return JSON.parse(text) as HealthchecksPayload;
  } catch {
    const params = new URLSearchParams(text);
    return Object.fromEntries(params.entries());
  }
}

function assertBearer(request: Request, token: string): void {
  const expected = `Bearer ${token}`;
  if (request.headers.get("Authorization") !== expected) {
    throw new HttpError(401, "unauthorized");
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
