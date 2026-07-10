import { getIncident, markFiringUpdate, markParentPosted, markResolved, prepareNewOccurrence, refreshLastSeen } from "./state";
import { postParent, postThread, updateParent } from "./slack";
import type { AlertmanagerPayload, CanonicalAlert, Env, Incident } from "./types";

const RETRY_DEDUPE_SECONDS = 30 * 60;

export async function handleAlertmanager(request: Request, env: Env, now: number): Promise<Response> {
  assertBearer(request, env.ALERTMANAGER_WEBHOOK_TOKEN);

  const payload = (await request.json()) as AlertmanagerPayload;
  const alerts = canonicalizeAlertmanagerPayload(payload, env);
  for (const alert of alerts) {
    await processAlert(env, alert, now);
  }

  return json({ ok: true, alerts: alerts.length });
}

export async function processAlert(env: Env, alert: CanonicalAlert, now: number): Promise<void> {
  const eventKey = makeEventKey(alert);
  const incident = await getIncident(env, alert.fingerprint);

  if (isDuplicateRetry(incident, eventKey, now)) {
    await refreshLastSeen(env, alert.fingerprint, now);
    return;
  }

  if (alert.status === "resolved") {
    await resolveAlert(env, alert, incident, eventKey, now);
    return;
  }

  if (!incident || incident.status === "resolved" || incident.status === "stale") {
    await createParent(env, alert, eventKey, now);
    return;
  }

  if (!incident.slack_ts || !incident.slack_channel_id) {
    await createParent(env, alert, eventKey, now);
    return;
  }

  const repeats = incident.repeats + 1;
  await updateParent(env, alert, incident.slack_channel_id, incident.slack_ts, now, repeats);
  await postThread(env, incident.slack_channel_id, incident.slack_ts, `${formatUnix(now)} still firing · repeat ${repeats}`);
  await markFiringUpdate(env, alert, eventKey, now, repeats);
}

async function createParent(env: Env, alert: CanonicalAlert, eventKey: string, now: number): Promise<void> {
  await prepareNewOccurrence(env, alert, now);
  const slackTs = await postParent(env, alert, now);
  await markParentPosted(env, alert.fingerprint, slackTs, eventKey, now);
  await postThread(env, alert.channelId, slackTs, `${formatUnix(now)} fired`);
}

async function resolveAlert(
  env: Env,
  alert: CanonicalAlert,
  incident: Incident | null,
  eventKey: string,
  now: number,
): Promise<void> {
  if (!incident || !incident.slack_ts || !incident.slack_channel_id) {
    return;
  }

  await updateParent(env, alert, incident.slack_channel_id, incident.slack_ts, now, incident.repeats);
  await postThread(env, incident.slack_channel_id, incident.slack_ts, `${formatUnix(now)} resolved`);
  await markResolved(env, alert, eventKey, now);
}

export function canonicalizeAlertmanagerPayload(payload: AlertmanagerPayload, env: Env): CanonicalAlert[] {
  const receiver = payload.receiver ?? "infra-alerts";
  const channelId = channelForReceiver(receiver, env);
  return (payload.alerts ?? []).map((alert) => {
    const labels = alert.labels ?? {};
    const annotations = alert.annotations ?? {};
    const alertname = labels.alertname ?? "UnknownAlert";
    const canonical: CanonicalAlert = {
      fingerprint: alert.fingerprint ?? fallbackFingerprint(labels),
      source: "alertmanager",
      receiver,
      status: alert.status ?? payload.status ?? "firing",
      severity: labels.severity ?? "unknown",
      alertname,
      summary: annotations.summary ?? alertname,
      description: annotations.description ?? "",
      labels,
      annotations,
      startsAt: alert.startsAt ?? new Date(0).toISOString(),
      endsAt: alert.endsAt ?? "",
      channelId,
    };
    if (payload.externalURL) canonical.externalURL = payload.externalURL;
    if (alert.generatorURL) canonical.sourceURL = alert.generatorURL;
    return canonical;
  });
}

function channelForReceiver(receiver: string, env: Env): string {
  if (receiver === "infra-audit") return env.SLACK_INFRA_AUDIT_CHANNEL_ID;
  return env.SLACK_INFRA_ALERTS_CHANNEL_ID;
}

function fallbackFingerprint(labels: Record<string, string>): string {
  return `labels:${Object.entries(labels)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`)
    .join(",")}`;
}

function makeEventKey(alert: CanonicalAlert): string {
  return `${alert.status}:${alert.startsAt}:${alert.endsAt}`;
}

function isDuplicateRetry(incident: Incident | null, eventKey: string, now: number): boolean {
  return Boolean(
    incident?.slack_ts &&
      incident.last_event_key === eventKey &&
      incident.last_event_at !== null &&
      now - incident.last_event_at < RETRY_DEDUPE_SECONDS,
  );
}

function assertBearer(request: Request, token: string): void {
  const expected = `Bearer ${token}`;
  if (request.headers.get("Authorization") !== expected) {
    throw new HttpError(401, "unauthorized");
  }
}

export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
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
