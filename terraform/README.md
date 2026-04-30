# Terraform

## Required Tokens

- Vultr
- GitHub
- Cloudflare

## Token Types and Permissions

### Vultr

- Just API token
- You may set allowed IPs in its API token access

### GitHub

#### Provisioning Token

- Classic Token with org: repo permissions

#### Buildbot

- Cloudflare DNS for `buildbot.sjanglab.org` points to eta (`141.164.53.203`), which proxies public traffic to the Buildbot stack on psi over wg-admin.

### Cloudflare

- Zone:Zone:Read
- Zone:DNS:Edit
- Zone:Zone Settings:Edit (for SSL)
