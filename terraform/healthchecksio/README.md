# healthchecks.io

This Terraform module owns infra dead-man checks and attaches the project Slack notification channel.

Managed checks:

- `rho-alertmanager-watchdog`: Prometheus → Alertmanager watchdog ping.
- `infra-alert-bridge-heartbeat`: Cloudflare Worker bridge cron heartbeat.

## Secrets

Replace the placeholder `HEALTHCHECKSIO_API_KEY` in `secrets.yaml` before running Terragrunt:

```bash
sops secrets.yaml
```

## Notification channel

Create the Slack integration in healthchecks.io before applying this module:

1. Open the healthchecks.io project settings.
2. Add a Slack integration.
3. Authorize the workspace.
4. Select `#infra-alerts` as the notification channel.

The provider can attach an existing Slack integration to the check, but it does
not perform Slack OAuth or create the integration itself.

## Apply

```bash
cd terraform/healthchecksio
direnv allow ..
terragrunt init
terragrunt plan
terragrunt apply
```

After apply, copy ping URLs into the matching SOPS files:

```bash
terragrunt output -raw rho_alertmanager_watchdog_ping_url
sops ../../modules/monitoring/secrets.yaml

terragrunt output -raw infra_alert_bridge_heartbeat_ping_url
sops ../alert-bridge/secrets.yaml
```

Store them as:

```yaml
# modules/monitoring/secrets.yaml
alertmanager-healthchecks-ping-url: ENC[...]

# terraform/alert-bridge/secrets.yaml
BRIDGE_HEARTBEAT_PING_URL: ENC[...]
```

Do not automate Terraform-to-SOPS writes from this module. Ping URLs are secrets: anyone who has one can send false healthy pings.
