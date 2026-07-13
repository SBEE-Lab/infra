# alert-bridge

Cloudflare deployment for the external Slack alert bridge.

This module manages:

- Cloudflare Worker script `infra-alert-bridge`.
- Cloudflare D1 database `infra-alert-bridge`.
- D1, plain text, and secret Worker bindings.
- Workers.dev subdomain enablement.
- Five-minute Worker cron trigger.

## Secrets

Create or edit `secrets.yaml` with SOPS:

```bash
sops secrets.yaml
```

Required keys:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ZONE_ID`
- `SLACK_BOT_TOKEN`
- `SLACK_INFRA_ALERTS_CHANNEL_ID`
- `SLACK_INFRA_AUDIT_CHANNEL_ID`
- `ALERTMANAGER_WEBHOOK_TOKEN`
- `HEALTHCHECKS_WEBHOOK_TOKEN`
- `BRIDGE_HEARTBEAT_PING_URL`

`CLOUDFLARE_ZONE_ID` can reuse the value from `terraform/cloudflare/secrets.yaml`; Terraform derives the account ID from that zone.

## Build Worker bundle

Terragrunt builds the Worker bundle automatically before `plan` and `apply`:

```bash
nix build ../..#infra-alert-bridge --no-link --print-out-paths
```

The hook writes the resulting Nix store path to the ignored local file
`worker.auto.tfvars.json`, so Terraform uploads the exact bundled `index.js`.

## Apply

```bash
cd terraform/alert-bridge
direnv allow ..
terragrunt init
terragrunt plan
terragrunt apply
```

## D1 migrations

The Terraform provider creates the D1 database but does not apply SQL migrations. After apply, run:

```bash
cd ../../packages/infra-alert-bridge
nix shell nixpkgs#nodejs -c npm ci
nix shell nixpkgs#nodejs -c npx wrangler d1 migrations apply infra-alert-bridge
```

Run migrations before routing Alertmanager or healthchecks.io traffic to the Worker.

## Cutover

Alertmanager uses `POST /alertmanager` with `Authorization: Bearer $ALERTMANAGER_WEBHOOK_TOKEN` from `modules/monitoring/prometheus/alertmanager.nix`.

Remaining cutover:

1. Verify `GET /healthz` on the Worker URL.
2. Confirm Alertmanager bridge posts and updates Slack messages successfully.
3. Point healthchecks.io webhooks to `POST /healthchecks` and send `Authorization: Bearer $HEALTHCHECKS_WEBHOOK_TOKEN`.
4. Keep legacy Slack incoming webhooks configured until the rollback window closes.
5. Remove legacy webhook secrets and Slack `incoming-webhook` scope after the rollback window.
