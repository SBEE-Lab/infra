#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
terraform/headscale manages only the singleton database ACL policy.

Headscale users are intentionally not Terraform-managed: Authentik is the
source of truth for user authorization, and Headscale creates OIDC users on
first login after allowed_groups authorization succeeds.

headscale_policy.tailnet cannot be imported because awlsring/headscale v0.5.1
does not implement ImportState for headscale_policy. First apply creates
Terraform state while setting the singleton database policy.
EOF
