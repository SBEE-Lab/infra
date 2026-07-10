import type { CanonicalAlert, Env, Incident } from "./types";

interface SlackResponse {
  ok: boolean;
  error?: string;
  ts?: string;
}

type SlackButton = { type: "button"; text: { type: "plain_text"; text: string }; url: string };

async function slackApi(env: Env, method: string, body: Record<string, unknown>): Promise<SlackResponse> {
  const response = await fetch(`https://slack.com/api/${method}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SLACK_BOT_TOKEN}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify(body),
  });

  const payload = (await response.json()) as SlackResponse;
  if (!response.ok || !payload.ok) {
    throw new Error(`Slack ${method} failed: ${payload.error ?? response.status}`);
  }
  return payload;
}

export async function postParent(env: Env, alert: CanonicalAlert, now: number): Promise<string> {
  const payload = messagePayload(alert, now, 0);
  const result = await slackApi(env, "chat.postMessage", {
    channel: alert.channelId,
    text: payload.text,
    blocks: payload.blocks,
    unfurl_links: false,
    unfurl_media: false,
  });

  if (!result.ts) {
    throw new Error("Slack chat.postMessage succeeded without ts");
  }
  return result.ts;
}

export async function updateParent(
  env: Env,
  alert: CanonicalAlert,
  channel: string,
  ts: string,
  now: number,
  repeats: number,
): Promise<void> {
  const payload = messagePayload(alert, now, repeats);
  await slackApi(env, "chat.update", {
    channel,
    ts,
    text: payload.text,
    blocks: payload.blocks,
  });
}

export async function postThread(env: Env, channel: string, threadTs: string, text: string): Promise<void> {
  await slackApi(env, "chat.postMessage", {
    channel,
    thread_ts: threadTs,
    text,
    unfurl_links: false,
    unfurl_media: false,
  });
}

export async function updateStaleParent(env: Env, incident: Incident, now: number): Promise<void> {
  if (!incident.slack_channel_id || !incident.slack_ts) return;
  const labels = parseJsonObject(incident.labels_json);
  const alert: CanonicalAlert = {
    fingerprint: incident.fingerprint,
    source: incident.source,
    receiver: incident.receiver,
    status: "firing",
    severity: incident.severity ?? "unknown",
    alertname: incident.alertname,
    summary: incident.summary ?? "Alert state is stale",
    description: incident.description ?? "No update received before stale threshold",
    labels,
    annotations: parseJsonObject(incident.annotations_json),
    startsAt: new Date(incident.first_seen * 1000).toISOString(),
    endsAt: "",
    channelId: incident.slack_channel_id,
  };

  const title = `⚠️ STALE ${alert.severity} · ${alert.alertname} · ${labelValue(alert, "service", "job", "host")}`;
  await slackApi(env, "chat.update", {
    channel: incident.slack_channel_id,
    ts: incident.slack_ts,
    text: title,
    blocks: baseBlocks(title, alert, now, incident.repeats, "STALE"),
  });
}

export function messagePayload(alert: CanonicalAlert, now: number, repeats: number): { text: string; blocks: unknown[] } {
  const emoji = alert.status === "resolved" ? "✅" : severityEmoji(alert.severity);
  const status = alert.status.toUpperCase();
  const title = `${emoji} ${status} ${alert.severity} · ${alert.alertname} · ${labelValue(alert, "service", "job", "host")}`;
  return { text: title, blocks: baseBlocks(title, alert, now, repeats, status) };
}

function baseBlocks(
  title: string,
  alert: CanonicalAlert,
  now: number,
  repeats: number,
  status: string,
): unknown[] {
  const fields = [
    field("Status", status),
    field("Severity", alert.severity),
    field("Service", labelValue(alert, "service", "job")),
    field("Host", labelValue(alert, "host", "instance")),
    field("Started", formatTime(alert.startsAt)),
    field(alert.status === "resolved" ? "Resolved" : "Last seen", formatUnix(now)),
  ];

  const blocks: unknown[] = [
    { type: "header", text: { type: "plain_text", text: truncate(title, 150) } },
    { type: "section", text: { type: "mrkdwn", text: truncate(`*${alert.summary}*\n${alert.description}`, 2900) } },
    { type: "section", fields },
  ];

  const actions = actionButtons(alert);
  if (actions.length > 0) {
    blocks.push({
      type: "actions",
      elements: actions,
    });
  }

  blocks.push({
    type: "context",
    elements: [
      {
        type: "mrkdwn",
        text: `source=${alert.source} · receiver=${alert.receiver ?? "-"} · repeats=${repeats} · fingerprint=${alert.fingerprint.slice(0, 12)}`,
      },
    ],
  });

  return blocks;
}

function actionButtons(alert: CanonicalAlert): SlackButton[] {
  return [
    actionButton("Alertmanager", alert.externalURL ? alertmanagerAlertsURL(alert.externalURL, alert) : undefined),
    actionButton("Source", alert.sourceURL),
    actionButton("Dashboard", annotationURL(alert, "dashboard_url", "grafana_url", "dashboard")),
    actionButton("Runbook", annotationURL(alert, "runbook_url", "runbook")),
  ].filter((button): button is SlackButton => Boolean(button));
}

function actionButton(text: string, url: string | undefined): SlackButton | undefined {
  if (!url || !isHttpURL(url)) return undefined;
  return {
    type: "button",
    text: { type: "plain_text", text },
    url,
  };
}

function annotationURL(alert: CanonicalAlert, ...keys: string[]): string | undefined {
  for (const key of keys) {
    const value = alert.annotations[key];
    if (value) return value;
  }
  return undefined;
}

function alertmanagerAlertsURL(value: string, alert: CanonicalAlert): string {
  const base = value.replace(/\/$/, "");
  if (base.includes("/#/")) return base;

  const filter = alertmanagerFilter(alert);
  const suffix = filter ? `?filter=${encodeURIComponent(filter)}` : "";
  return `${base}/#/alerts${suffix}`;
}

function alertmanagerFilter(alert: CanonicalAlert): string {
  const labels = ["alertname", "severity", "host", "service", "job", "instance"]
    .map((key) => [key, alert.labels[key]] as const)
    .filter((entry): entry is readonly [string, string] => Boolean(entry[1]));
  if (labels.length === 0) return "";
  return `{${labels.map(([key, value]) => `${key}="${escapeMatcherValue(value)}"`).join(",")}}`;
}

function escapeMatcherValue(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function isHttpURL(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function field(label: string, value: string): { type: "mrkdwn"; text: string } {
  return { type: "mrkdwn", text: `*${label}*\n${value || "-"}` };
}

function severityEmoji(severity: string): string {
  if (severity === "critical") return "🚨";
  if (severity === "warning") return "⚠️";
  return "ℹ️";
}

function labelValue(alert: CanonicalAlert, ...keys: string[]): string {
  for (const key of keys) {
    const value = alert.labels[key];
    if (value) return value;
  }
  return "unknown";
}

function formatTime(value: string): string {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.valueOf())) return value;
  return formatUnix(Math.floor(date.valueOf() / 1000));
}

function formatUnix(value: number): string {
  return new Date(value * 1000).toISOString();
}

function truncate(value: string, maxLength: number): string {
  return value.length <= maxLength ? value : `${value.slice(0, maxLength - 1)}…`;
}

function parseJsonObject(value: string): Record<string, string> {
  const parsed = JSON.parse(value) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
  return Object.fromEntries(
    Object.entries(parsed).filter((entry): entry is [string, string] => typeof entry[1] === "string"),
  );
}
