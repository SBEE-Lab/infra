export interface Env {
  DB: D1Database;
  SLACK_BOT_TOKEN: string;
  SLACK_INFRA_ALERTS_CHANNEL_ID: string;
  SLACK_INFRA_AUDIT_CHANNEL_ID: string;
  ALERTMANAGER_WEBHOOK_TOKEN: string;
  HEALTHCHECKS_WEBHOOK_TOKEN: string;
  BRIDGE_HEARTBEAT_PING_URL?: string;
  VERSION?: string;
}

export type IncidentStatus = "firing" | "resolved" | "stale";
export type IncidentSource = "alertmanager" | "healthchecks";

export interface Incident {
  fingerprint: string;
  source: IncidentSource;
  receiver: string | null;
  status: IncidentStatus;
  severity: string | null;
  alertname: string;
  summary: string | null;
  description: string | null;
  labels_json: string;
  annotations_json: string;
  slack_channel_id: string | null;
  slack_ts: string | null;
  list_row_id: string | null;
  first_seen: number;
  last_seen: number;
  resolved_at: number | null;
  repeats: number;
  last_event_key: string | null;
  last_event_at: number | null;
}

export interface CanonicalAlert {
  fingerprint: string;
  source: IncidentSource;
  receiver: string | null;
  status: "firing" | "resolved";
  severity: string;
  alertname: string;
  summary: string;
  description: string;
  labels: Record<string, string>;
  annotations: Record<string, string>;
  startsAt: string;
  endsAt: string;
  externalURL?: string;
  sourceURL?: string;
  channelId: string;
}

export interface AlertmanagerPayload {
  receiver?: string;
  status?: "firing" | "resolved";
  externalURL?: string;
  alerts?: AlertmanagerAlert[];
}

export interface AlertmanagerAlert {
  status?: "firing" | "resolved";
  labels?: Record<string, string>;
  annotations?: Record<string, string>;
  startsAt?: string;
  endsAt?: string;
  generatorURL?: string;
  fingerprint?: string;
}
