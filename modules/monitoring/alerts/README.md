# Monitoring alert delivery

This directory declares the Slack-facing alert delivery pieces for the monitoring stack.

## Layout

- `slack-app/`: Slack app manifest and Slack CLI project for the `SjangLab Infra Alerts` app.
- `flake-module.nix`: dev shell with the Slack CLI and manifest validation tools.

The external alert bridge implementation lives under `packages/infra-alert-bridge` and its Cloudflare deployment lives under `terraform/alert-bridge`.

## Current flow

Alertmanager sends Slack notifications through the Cloudflare Worker bridge so firing, update, and resolved events can share Slack threads.

```text
Prometheus -> Alertmanager -> external alert bridge -> Slack Web API
Watchdog -> healthchecks.io -> Slack integration
```

Watchdog pings healthchecks.io directly and never depends on the bridge. The bridge has its own `infra-alert-bridge-heartbeat` healthchecks.io dead-man check.

## Remaining bridge cutover

healthchecks.io can later move from its Slack integration to `POST /healthchecks` on the bridge with `Authorization: Bearer $HEALTHCHECKS_WEBHOOK_TOKEN`.

Rollback checklist:

1. Restore Alertmanager `slack_configs` with the legacy incoming webhook secrets.
2. Keep the healthchecks.io Slack integration in place until bridge healthchecks delivery is confirmed.
3. Remove `incoming-webhook` scope and SOPS webhook secrets after the rollback window.

See `slack-app/README.md` for Slack app bootstrap and drift checks.
