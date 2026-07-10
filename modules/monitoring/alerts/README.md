# Monitoring alert delivery

This directory declares the Slack-facing alert delivery pieces for the monitoring stack.

## Layout

- `slack-app/`: Slack app manifest and Slack CLI project for the `SjangLab Infra Alerts` app.
- `flake-module.nix`: dev shell with the Slack CLI and manifest validation tools.

The external alert bridge implementation lives under `packages/infra-alert-bridge` and its Cloudflare deployment lives under `terraform/alert-bridge`.

## Current flow

Alertmanager still sends Slack notifications through incoming webhooks. The Cloudflare Worker bridge is deployed separately and ready for cutover after D1 migrations and receiver URL changes.

```text
Prometheus -> Alertmanager -> Slack incoming webhook
Watchdog -> healthchecks.io -> Slack integration
```

## Bridge cutover target

```text
Prometheus -> Alertmanager -> external alert bridge -> Slack Web API
Watchdog -> healthchecks.io -> external alert bridge -> Slack Web API
```

Watchdog pings healthchecks.io directly and never depends on the bridge. The bridge has its own `infra-alert-bridge-heartbeat` healthchecks.io dead-man check.

Cutover checklist:

1. Apply `terraform/alert-bridge`.
2. Run D1 migrations from `packages/infra-alert-bridge`.
3. Configure Alertmanager `webhook_configs` to `POST /alertmanager` with bearer token.
4. Configure healthchecks.io webhook integration to `POST /healthchecks` with bearer token.
5. Keep legacy Slack webhooks until bridge messages are confirmed.
6. Remove `incoming-webhook` scope and SOPS webhook secrets after rollback window.

See `slack-app/README.md` for Slack app bootstrap and drift checks.
