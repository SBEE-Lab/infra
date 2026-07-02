#!/usr/bin/env bash
set -euo pipefail

AK=${AK:-https://auth.sjanglab.org}
AK_TOKEN=${AK_TOKEN:-$(sops -d --extract '["AUTHENTIK_TOKEN"]' secrets.yaml)}
TG=${TG:-terragrunt}

api() {
  curl -sSf -H "Authorization: Bearer ${AK_TOKEN}" "$AK/api/v3/$1"
}

state_has() {
  $TG state show "$1" >/dev/null 2>&1
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

json_quote() {
  jq -Rn --arg v "$1" '$v'
}

group_id_by_name() {
  local name=$1
  api "core/groups/?search=$(jq -rn --arg v "$name" '$v|@uri')&page_size=100" |
    jq -r --arg name "$name" '.results[] | select(.name == $name) | .pk' |
    head -n1
}

user_id_by_username() {
  local username=$1
  api "core/users/?search=$(jq -rn --arg v "$username" '$v|@uri')&page_size=100" |
    jq -r --arg username "$username" '.results[] | select(.username == $username) | .pk' |
    head -n1
}

proxy_id_by_external_host() {
  local external_host=$1
  api "providers/proxy/?page_size=100" |
    jq -r --arg external_host "$external_host" '.results[] | select(.external_host == $external_host) | .pk' |
    head -n1
}

app_uuid_by_slug() {
  local slug=$1
  curl -sS -H "Authorization: Bearer ${AK_TOKEN}" "$AK/api/v3/core/applications/${slug}/" 2>/dev/null |
    jq -r '.pk // empty' 2>/dev/null || true
}

policy_id_by_name() {
  local name=$1
  api "policies/expression/?search=$(jq -rn --arg v "$name" '$v|@uri')&page_size=100" |
    jq -r --arg name "$name" '.results[] | select(.name == $name) | .pk' |
    head -n1
}

binding_id_by_target_policy() {
  local target=$1
  local policy=$2
  api "policies/bindings/?target=${target}&page_size=100" |
    jq -r --arg policy "$policy" '.results[] | select(.policy == $policy) | .pk' |
    head -n1
}

outpost_id=$(api 'outposts/instances/?search=authentik%20Embedded%20Outpost&page_size=100' |
  jq -r '.results[] | select(.name == "authentik Embedded Outpost") | .pk' |
  head -n1)

# Keep keys in sync with local.groups in groups.tf.
while IFS='|' read -r key name; do
  import_if_missing "authentik_group.group[$(json_quote "$key")]" "$(group_id_by_name "$name")"
done <<'EOF'
authentik_admins|authentik Admins
sjanglab_admins|sjanglab-admins
sjanglab_researchers|sjanglab-researchers
sjanglab_students|sjanglab-students
EOF

while IFS= read -r username; do
  import_if_missing "authentik_user.user[$(json_quote "$username")]" "$(user_id_by_username "$username")"
done < <(sops -d users.yaml | yq -r '.users[].username')

while IFS='|' read -r key name; do
  import_if_missing "authentik_policy_expression.forward_auth[$(json_quote "$key")]" "$(policy_id_by_name "$name")"
done <<'EOF'
admins|sjanglab-forward-auth-admin-access
researchers|sjanglab-forward-auth-access
EOF

policy_name_for_key() {
  case "$1" in
  admins) echo 'sjanglab-forward-auth-admin-access' ;;
  researchers) echo 'sjanglab-forward-auth-access' ;;
  *)
    echo "unknown policy key: $1" >&2
    return 1
    ;;
  esac
}

while IFS='|' read -r app external_host policy_key; do
  provider_id=$(proxy_id_by_external_host "$external_host")
  app_id=$(app_uuid_by_slug "$app")
  policy_name=$(policy_name_for_key "$policy_key")
  policy_id=$(policy_id_by_name "$policy_name")

  import_if_missing "authentik_provider_proxy.app[$(json_quote "$app")]" "$provider_id"
  if [ -n "$app_id" ]; then
    import_if_missing "authentik_application.app[$(json_quote "$app")]" "$app"
  else
    echo "skip application for $app: no remote object"
  fi

  if [ -n "$outpost_id" ] && [ -n "$provider_id" ]; then
    import_if_missing "authentik_outpost_provider_attachment.embedded[$(json_quote "$app")]" "${outpost_id}:${provider_id}"
  else
    echo "skip outpost attachment for $app: no outpost/provider"
  fi

  if [ -n "$app_id" ] && [ -n "$policy_id" ]; then
    import_if_missing "authentik_policy_binding.app_access[$(json_quote "$app")]" "$(binding_id_by_target_policy "$app_id" "$policy_id")"
  else
    echo "skip policy binding for $app: no app/policy"
  fi
done <<'EOF'
n8n|https://n8n.sjanglab.org|researchers
gatus|https://gatus.sjanglab.org|admins
logging|https://logging.sjanglab.org|admins
multievolve|https://multievolve.sjanglab.org|researchers
EOF
