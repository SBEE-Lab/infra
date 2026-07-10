import { handleAlertmanager, HttpError } from "./alertmanager";
import { handleHealthchecks } from "./healthchecks";
import { markStale, staleIncidents } from "./state";
import { postThread, updateStaleParent } from "./slack";
import type { Env } from "./types";

const STALE_AFTER_SECONDS = 49 * 60 * 60;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const now = Math.floor(Date.now() / 1000);
    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/healthz") {
        return json({ ok: true, version: env.VERSION ?? "dev" });
      }
      if (request.method === "POST" && url.pathname === "/alertmanager") {
        return await handleAlertmanager(request, env, now);
      }
      if (request.method === "POST" && url.pathname === "/healthchecks") {
        return await handleHealthchecks(request, env, now);
      }
      return json({ ok: false, error: "not_found" }, 404);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ ok: false, error: error.message }, error.status);
      }
      console.error(error);
      return json({ ok: false, error: "internal_error" }, 500);
    }
  },

  async scheduled(_event: ScheduledEvent, env: Env, _ctx: ExecutionContext): Promise<void> {
    const now = Math.floor(Date.now() / 1000);
    await sweepStale(env, now);
    await pingHeartbeat(env);
  },
};

async function sweepStale(env: Env, now: number): Promise<void> {
  const incidents = await staleIncidents(env, now - STALE_AFTER_SECONDS);
  for (const incident of incidents) {
    const eventKey = `stale:${now}`;
    await updateStaleParent(env, incident, now);
    if (incident.slack_channel_id && incident.slack_ts) {
      await postThread(env, incident.slack_channel_id, incident.slack_ts, `${formatUnix(now)} marked stale`);
    }
    await markStale(env, incident.fingerprint, eventKey, now);
  }
}

async function pingHeartbeat(env: Env): Promise<void> {
  if (!env.BRIDGE_HEARTBEAT_PING_URL) return;
  const response = await fetch(env.BRIDGE_HEARTBEAT_PING_URL, { method: "GET" });
  if (!response.ok) {
    throw new Error(`heartbeat ping failed: ${response.status}`);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function formatUnix(value: number): string {
  return new Date(value * 1000).toISOString();
}
