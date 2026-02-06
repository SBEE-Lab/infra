# Sync node tags declaratively
#
# Ensures node tags match the declared configuration.
# Runs at boot and periodically to maintain consistency.
{ pkgs, ... }:
let
  # Node name → tags mapping
  nodeTags = {
    psi = [
      "tag:ai"
      "tag:server"
    ];
    rho = [
      "tag:ai"
      "tag:monitoring"
      "tag:server"
    ];
    tau = [
      "tag:apps"
      "tag:server"
    ];
  };

  nodeTagsJson = builtins.toJSON nodeTags;

  syncScript = pkgs.writeShellScript "headscale-tag-sync" ''
    set -euo pipefail

    HEADSCALE="${pkgs.headscale}/bin/headscale"
    JQ="${pkgs.jq}/bin/jq"

    # Get current nodes
    nodes=$($HEADSCALE nodes list -o json 2>/dev/null || echo "[]")

    # Declared tags
    declared='${nodeTagsJson}'

    # Sync each node
    echo "$nodes" | $JQ -r '.[] | "\(.id) \(.name)"' | while read -r id name; do
      # Get declared tags for this node
      tags=$(echo "$declared" | $JQ -r --arg name "$name" '.[$name] // [] | join(",")')

      if [ -n "$tags" ]; then
        current=$($HEADSCALE nodes list -o json | $JQ -r --argjson id "$id" '.[] | select(.id == $id) | .forcedTags // [] | join(",")')

        if [ "$current" != "$tags" ]; then
          echo "Updating $name (id=$id): $tags"
          $HEADSCALE nodes tag -i "$id" -t "$tags" || true
        fi
      fi
    done

    echo "Tag sync complete"
  '';
in
{
  systemd.services.headscale-tag-sync = {
    description = "Sync node tags to Headscale";
    after = [ "headscale.service" ];
    wants = [ "headscale.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${syncScript}";
    };
  };

  systemd.timers.headscale-tag-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
      RandomizedDelaySec = "1min";
    };
  };
}
