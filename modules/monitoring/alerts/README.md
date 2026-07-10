# Monitoring alert delivery

This directory declares the Slack-facing alert delivery pieces for the monitoring stack.

## Layout

- `slack-app/`: Slack app manifest and Slack CLI project for the `SjangLab Infra Alerts` app.
- `flake-module.nix`: dev shell with the Slack CLI and manifest validation tools.

The external alert bridge and Cloudflare deployment are planned separately under `packages/infra-alert-bridge` and `terraform/alert-bridge`.

## Current flow

Alertmanager still sends Slack notifications through incoming webhooks while the bridge is being built. The Slack app manifest already includes `chat:write` so the bridge can later post and update messages through the Slack Web API.

## Desired flow

```text
Prometheus -> Alertmanager -> external alert bridge -> Slack Web API
Watchdog -> healthchecks.io -> external alert bridge -> Slack Web API
```

Watchdog pings healthchecks.io directly and never depends on the bridge. The bridge will have its own healthchecks.io dead-man check.

See `slack-app/README.md` for Slack app bootstrap and drift checks.
