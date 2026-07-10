# infra-alert-bridge

Cloudflare Worker that receives Alertmanager and healthchecks.io webhooks and posts stateful Slack notifications.

## Endpoints

- `POST /alertmanager` — Alertmanager webhook payloads. Requires `Authorization: Bearer $ALERTMANAGER_WEBHOOK_TOKEN`.
- `POST /healthchecks` — healthchecks.io webhook payloads. Requires `Authorization: Bearer $HEALTHCHECKS_WEBHOOK_TOKEN`.
- `GET /healthz` — unauthenticated health probe.

## Slack messages

Alertmanager notifications include action buttons when source data is present:

- `Alertmanager` links to the Alertmanager alerts view from `externalURL`.
- `Source` links to the per-alert `generatorURL` from Prometheus.
- `Dashboard` and `Runbook` use `dashboard_url` and `runbook_url` annotations.

Dedupe metadata such as source, receiver, repeats, and fingerprint is shown in a compact context block.

## State

D1 stores incident state and Slack message timestamps. Apply migrations before deployment:

```bash
wrangler d1 migrations apply infra-alert-bridge
```

## Local smoke

```bash
wrangler dev
curl -X POST http://localhost:8787/alertmanager \
  -H 'Authorization: Bearer test' \
  -H 'Content-Type: application/json' \
  --data @fixtures/alertmanager-firing.json
```

## Required secrets

- `SLACK_BOT_TOKEN`
- `SLACK_INFRA_ALERTS_CHANNEL_ID`
- `SLACK_INFRA_AUDIT_CHANNEL_ID`
- `ALERTMANAGER_WEBHOOK_TOKEN`
- `HEALTHCHECKS_WEBHOOK_TOKEN`
- `BRIDGE_HEARTBEAT_PING_URL`
