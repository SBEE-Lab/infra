# Terraform

## State backend

Terragrunt stores state in the private `sjanglab-terraform-state` Cloudflare R2 bucket. The `terraform/.envrc` direnv environment loads bucket-scoped S3 credentials from `terraform/secrets.yaml`; native S3 lock files serialize state writes.

## Provider environment

Nix is the single authority for OpenTofu and provider versions. Use the Terraform
shell (`nix develop .#terraform`) or reload the Terraform direnv environment after
reviewing changes to `.envrc`. The `.envrc` also supplies the existing R2 backend
credentials; entering the Nix shell alone does not load those secrets.

The shell disables Terragrunt provider caches and selects the Nix-packaged
OpenTofu. A guard rejects a different executable, external provider caches or CLI
configuration, disabled auto-init, and overridden data/download directories.
These checks prevent accidental environment mixing, not deliberate bypasses.

Each unit keeps its execution directory under
`.terragrunt-cache/<Nix-package-basename>/`. A changed OpenTofu or provider package
gets a fresh cache and auto-initializes before planning. The same environment
reuses its initialized cache. Source `.terraform/` directories and lock files are
not copied, and generated locks stay in the cache rather than Git. Update Nix
inputs to change provider versions; do not separately pin registry versions or
run `init -upgrade` against production caches to work around a mismatch.

For a missing-provider error, reload the declared environment, then run `init`
and create a new plan in the affected unit. Do not delete shared caches or remote
state. Old caches are left intact for existing operations.

Auto-init during `apply` is rejected: initialize and review a new plan first. Keep
saved plans outside disposable caches using an absolute `-out` path, restrict
their permissions because they may contain secrets, and use the same flake
revision, platform, and provider environment through apply. Applying still needs
explicit approval.

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

- Cloudflare DNS for `nixbot.sjanglab.org` points to eta (`141.164.53.203`), which proxies public traffic to the Nixbot stack on psi over wg-admin.

### Cloudflare

- Zone:Zone:Read
- Zone:DNS:Edit
- Zone:Zone Settings:Edit (for SSL)

### healthchecks.io

- API key with permission to manage checks in the target project
