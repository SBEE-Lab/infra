# Sync Authentik groups → Headscale ACL policy.json
#
# Merges dynamic groups from Authentik API with static ACL rules.
# Headscale auto-reloads policy.json on file change (inotify).
{ config, pkgs, ... }:
let
  aclRules = import ./acl-rules.nix;
  policyPath = "/var/lib/headscale/policy.json";

  syncScript = pkgs.writeShellScript "headscale-acl-sync" ''
    set -euo pipefail

    AUTHENTIK_URL="https://auth.sjanglab.org"
    TOKEN=$(< "$CREDENTIALS_DIRECTORY/authentik-api-token")

    # Fetch groups with members from Authentik
    response=$(${pkgs.curl}/bin/curl -sf \
      -H "Authorization: Bearer $TOKEN" \
      "$AUTHENTIK_URL/api/v3/core/groups/?include_users=true&page_size=100")

    # Build groups JSON: map Authentik groups to headscale ACL groups
    # Only include sjanglab-* groups; map usernames for headscale
    groups=$(echo "$response" | ${pkgs.jq}/bin/jq -c '
      [.results[] | select(.name | startswith("sjanglab-"))] |
      map({
        key: ("group:" + .name),
        value: [.users_obj[]? | .username]
      }) | from_entries
    ')

    # Merge dynamic groups with static rules
    policy=$(${pkgs.jq}/bin/jq -nc \
      --argjson groups "$groups" \
      --slurpfile rules ${pkgs.writeText "acl-rules.json" (builtins.toJSON aclRules)} \
      '$rules[0] + {groups: $groups}')

    # Atomic write
    tmp=$(mktemp -p /var/lib/headscale)
    echo "$policy" > "$tmp"
    mv "$tmp" "${policyPath}"

    echo "ACL sync complete: $(echo "$groups" | ${pkgs.jq}/bin/jq -r 'to_entries | map(.key + ": " + (.value | length | tostring)) | join(", ")')"
  '';
in
{
  sops.secrets.authentik-api-token = {
    sopsFile = ./secrets.yaml;
    owner = "headscale";
    group = "headscale";
    mode = "0400";
  };

  systemd.services.headscale-acl-sync = {
    description = "Sync Authentik groups to Headscale ACL policy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "headscale";
      Group = "headscale";
      LoadCredential = [
        "authentik-api-token:${config.sops.secrets.authentik-api-token.path}"
      ];
    };
    script = "${syncScript}";
  };

  systemd.timers.headscale-acl-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "15min";
      RandomizedDelaySec = "1min";
    };
  };
}
