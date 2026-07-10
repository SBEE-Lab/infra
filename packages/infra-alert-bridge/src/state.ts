import type { CanonicalAlert, Env, Incident } from "./types";

export async function getIncident(env: Env, fingerprint: string): Promise<Incident | null> {
  const row = await env.DB.prepare("SELECT * FROM incidents WHERE fingerprint = ?")
    .bind(fingerprint)
    .first<Incident>();
  return row ?? null;
}

export async function refreshLastSeen(env: Env, fingerprint: string, lastSeen: number): Promise<void> {
  await env.DB.prepare("UPDATE incidents SET last_seen = ? WHERE fingerprint = ?")
    .bind(lastSeen, fingerprint)
    .run();
}

export async function prepareNewOccurrence(env: Env, alert: CanonicalAlert, now: number): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO incidents (
      fingerprint, source, receiver, status, severity, alertname, summary, description,
      labels_json, annotations_json, slack_channel_id, slack_ts, first_seen, last_seen,
      resolved_at, repeats, last_event_key, last_event_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, NULL, 0, NULL, NULL)
    ON CONFLICT(fingerprint) DO UPDATE SET
      source = excluded.source,
      receiver = excluded.receiver,
      status = excluded.status,
      severity = excluded.severity,
      alertname = excluded.alertname,
      summary = excluded.summary,
      description = excluded.description,
      labels_json = excluded.labels_json,
      annotations_json = excluded.annotations_json,
      slack_channel_id = excluded.slack_channel_id,
      slack_ts = NULL,
      first_seen = excluded.first_seen,
      last_seen = excluded.last_seen,
      resolved_at = NULL,
      repeats = 0,
      last_event_key = NULL,
      last_event_at = NULL`,
  )
    .bind(
      alert.fingerprint,
      alert.source,
      alert.receiver,
      alert.status,
      alert.severity,
      alert.alertname,
      alert.summary,
      alert.description,
      JSON.stringify(alert.labels),
      JSON.stringify(alert.annotations),
      alert.channelId,
      now,
      now,
    )
    .run();
}

export async function markParentPosted(
  env: Env,
  fingerprint: string,
  slackTs: string,
  eventKey: string,
  now: number,
): Promise<void> {
  await env.DB.prepare(
    `UPDATE incidents
       SET slack_ts = ?, last_event_key = ?, last_event_at = ?
     WHERE fingerprint = ?`,
  )
    .bind(slackTs, eventKey, now, fingerprint)
    .run();
}

export async function markFiringUpdate(
  env: Env,
  alert: CanonicalAlert,
  eventKey: string,
  now: number,
  repeats: number,
): Promise<void> {
  await env.DB.prepare(
    `UPDATE incidents SET
      receiver = ?, status = 'firing', severity = ?, alertname = ?, summary = ?, description = ?,
      labels_json = ?, annotations_json = ?, slack_channel_id = ?, last_seen = ?, resolved_at = NULL,
      repeats = ?, last_event_key = ?, last_event_at = ?
     WHERE fingerprint = ?`,
  )
    .bind(
      alert.receiver,
      alert.severity,
      alert.alertname,
      alert.summary,
      alert.description,
      JSON.stringify(alert.labels),
      JSON.stringify(alert.annotations),
      alert.channelId,
      now,
      repeats,
      eventKey,
      now,
      alert.fingerprint,
    )
    .run();
}

export async function markResolved(
  env: Env,
  alert: CanonicalAlert,
  eventKey: string,
  now: number,
): Promise<void> {
  await env.DB.prepare(
    `UPDATE incidents SET
      receiver = ?, status = 'resolved', severity = ?, alertname = ?, summary = ?, description = ?,
      labels_json = ?, annotations_json = ?, slack_channel_id = ?, last_seen = ?, resolved_at = ?,
      last_event_key = ?, last_event_at = ?
     WHERE fingerprint = ?`,
  )
    .bind(
      alert.receiver,
      alert.severity,
      alert.alertname,
      alert.summary,
      alert.description,
      JSON.stringify(alert.labels),
      JSON.stringify(alert.annotations),
      alert.channelId,
      now,
      now,
      eventKey,
      now,
      alert.fingerprint,
    )
    .run();
}

export async function staleIncidents(env: Env, cutoff: number): Promise<Incident[]> {
  const result = await env.DB.prepare(
    "SELECT * FROM incidents WHERE status = 'firing' AND last_seen < ? AND slack_ts IS NOT NULL",
  )
    .bind(cutoff)
    .all<Incident>();
  return result.results ?? [];
}

export async function markStale(env: Env, fingerprint: string, eventKey: string, now: number): Promise<void> {
  await env.DB.prepare(
    `UPDATE incidents SET status = 'stale', last_event_key = ?, last_event_at = ? WHERE fingerprint = ?`,
  )
    .bind(eventKey, now, fingerprint)
    .run();
}
