#!/usr/bin/env bash
set -euo pipefail

HS=${HS:-https://hs.sjanglab.org}
HS_TOKEN=${HS_TOKEN:-$(sops -d --extract '["HEADSCALE_API_KEY"]' secrets.yaml)}
TG=${TG:-terragrunt}

api() {
  curl -sSf -H "Authorization: Bearer ${HS_TOKEN}" "$HS/api/v1/$1"
}

state_has() {
  $TG state show "$1" >/dev/null 2>&1
}

json_quote() {
  jq -Rn --arg v "$1" '$v'
}

import_if_missing() {
  local address=$1
  local id=$2

  if [ -z "$id" ] || [ "$id" = "null" ]; then
    echo "skip $address: no remote object"
    return 0
  fi

  if state_has "$address"; then
    echo "ok $address already imported"
    return 0
  fi

  echo "import $address <- $id"
  $TG import "$address" "$id"
}

user_id_by_name() {
  local name=$1
  api "user" |
    jq -r --arg name "$name" '.users[] | select(.name == $name) | .id' |
    head -n1
}

while IFS= read -r username; do
  import_if_missing "headscale_user.user[$(json_quote "$username")]" "$(user_id_by_name "$username")"
done < <(sops -d ../authentik/users.yaml | yq -r '.users[].username | select(test("@"))')

cat <<'EOF'

note: headscale_policy.tailnet cannot be imported because awlsring/headscale v0.5.1 does not implement ImportState for headscale_policy. First apply will create Terraform state while setting the singleton database policy.
EOF
