# healthchecks.io

This Terraform module owns the `rho-alertmanager-watchdog` check used by the
Alertmanager dead-man route and attaches the project Slack notification channel.

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

After apply, copy the ping URL into the monitoring SOPS file:

```bash
terragrunt output -raw rho_alertmanager_watchdog_ping_url
sops modules/monitoring/secrets.yaml
```

Store it as:

```yaml
alertmanager-healthchecks-ping-url: ENC[...]
```

Do not automate Terraform-to-SOPS writes from this module. The ping URL is a
secret: anyone who has it can send false healthy pings.
