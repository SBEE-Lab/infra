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

- Cloudflare DNS for `buildbot.sjanglab.org` points directly to psi (`117.16.251.37`).

### Cloudflare

- Zone:Zone:Read
- Zone:DNS:Edit
- Zone:Zone Settings:Edit (for SSL)
