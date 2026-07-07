# Terraform

## State backend

Terragrunt uses PostgreSQL state on rho through `terraform/tunnel.sh`. The `terraform/.envrc` direnv environment loads the backend password from `terraform/secrets.yaml`.

## Required Tokens

- Vultr
- GitHub
- Cloudflare
- healthchecks.io

## Token Types and Permissions

### Vultr

- Just API token
- You may set allowed IPs in its API token access

### GitHub

#### Provisioning Token

- Classic Token with org: repo permissions

#### Nixbot

- Cloudflare DNS for `buildbot.sjanglab.org` points to eta (`141.164.53.203`), which proxies public traffic to the Nixbot stack on psi over wg-admin.

### Cloudflare

- Zone:Zone:Read
- Zone:DNS:Edit
- Zone:Zone Settings:Edit (for SSL)

### healthchecks.io

- API key with permission to manage checks in the target project
