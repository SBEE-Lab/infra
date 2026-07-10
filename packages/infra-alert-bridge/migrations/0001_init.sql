CREATE TABLE IF NOT EXISTS incidents (
  fingerprint TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  receiver TEXT,
  status TEXT NOT NULL,
  severity TEXT,
  alertname TEXT NOT NULL,
  summary TEXT,
  description TEXT,
  labels_json TEXT NOT NULL,
  annotations_json TEXT NOT NULL,
  slack_channel_id TEXT,
  slack_ts TEXT,
  list_row_id TEXT,
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  resolved_at INTEGER,
  repeats INTEGER NOT NULL DEFAULT 0,
  last_event_key TEXT,
  last_event_at INTEGER
);

CREATE INDEX IF NOT EXISTS incidents_status_idx ON incidents(status);
CREATE INDEX IF NOT EXISTS incidents_last_seen_idx ON incidents(last_seen);
