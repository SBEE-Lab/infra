# Headscale control-plane audit collection
# - Classifies node registration/expiry, preauth key, and OIDC denial events
#   from headscale JSON logs (requires settings.log.format = "json")
# - Snapshots node inventory periodically for tailnet membership audit
# Only bounded values (host/log_type/event) become Loki labels; user, node,
# and IP stay in the JSON body to keep stream cardinality low.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking) hostName;
  lokiEndpoint = "http://${config.networking.sbee.hosts.rho.wg-admin}:3100";

  # Field names differ across headscale versions (snake_case vs camelCase),
  # so accept both when flattening the node list into one JSON line per node.
  # Summary rows let Grafana count online nodes without double-counting
  # repeated per-node snapshots in a range query.
  nodesSnapshotScript = pkgs.writeShellScript "headscale-nodes-snapshot" ''
    ${lib.getExe config.services.headscale.package} nodes list --output json |
      ${lib.getExe pkgs.jq} -c '
        def seconds($value):
          if ($value | type) == "object" then ($value.seconds // null)
          elif $value == null then null
          else $value
          end;
        def expiry_seconds($node): seconds($node.expiry);
        def last_seen_seconds($node): seconds($node.last_seen // $node.lastSeen);
        def node_name($node): ($node.given_name // $node.givenName // $node.name // "");
        def node_tags($node): ($node.tags // []);
        def node_user($node): ($node.user.name // "");
        def is_server($node): (node_tags($node) | index("tag:server")) != null;
        def expiry_never($node): (expiry_seconds($node) // -62135596800) < 0;
        def near_expiry($node):
          (expiry_seconds($node) // -62135596800) as $expiry |
          $expiry > 0 and $expiry >= now and $expiry < (now + 2592000);
        def expired($node):
          (expiry_seconds($node) // -62135596800) as $expiry |
          $expiry > 0 and $expiry < now;
        def stale($node):
          (last_seen_seconds($node) // 0) as $last_seen |
          (is_server($node) | not) and $last_seen > 0 and $last_seen < (now - 2592000);
        def generic_name($node):
          (node_name($node) | test("^(localhost|invalid-)"));
        def server_offline($node): is_server($node) and (($node.online // false) != true);
        def server_expiring($node): is_server($node) and (expiry_never($node) | not);
        def unmanaged_never_expiry($node):
          (is_server($node) | not) and expiry_never($node) and ((node_tags($node) | length) == 0);
        def health_reasons($node):
          [
            (if server_offline($node) then "server_offline" else empty end),
            (if server_expiring($node) then "server_expiring" else empty end),
            (if stale($node) then "stale" else empty end),
            (if near_expiry($node) then "near_expiry" else empty end),
            (if generic_name($node) then "generic_name" else empty end),
            (if unmanaged_never_expiry($node) then "untagged_never_expiry" else empty end)
          ];
        def health($node):
          if server_offline($node) or server_expiring($node) then "FAIL"
          elif (health_reasons($node) | length) > 0 then "WARN"
          else "OK"
          end;
        def node_row:
          {
            log_type: "headscale_nodes",
            event: "node_snapshot",
            host: "${hostName}",
            node_id: ((.id // "") | tostring),
            node: node_name(.),
            user: node_user(.),
            ip_addresses: ((.ip_addresses // .ipAddresses // []) | join(",")),
            tags: (node_tags(.) | join(",")),
            server: (is_server(.) | tostring),
            online: ((.online // false) | tostring),
            health: health(.),
            health_reason: (health_reasons(.) | join(",")),
            last_seen_seconds: last_seen_seconds(.),
            expiry_seconds: expiry_seconds(.)
          };
        (. // []) as $nodes |
        ($nodes[] | node_row),
        {
          log_type: "headscale_nodes",
          event: "nodes_summary",
          host: "${hostName}",
          total_count: ($nodes | length),
          online_count: ($nodes | map(select((.online // false) == true)) | length),
          expired_count: ($nodes | map(select(expired(.))) | length),
          near_expiry_count: ($nodes | map(select(near_expiry(.))) | length),
          stale_count: ($nodes | map(select(stale(.))) | length),
          server_offline_count: ($nodes | map(select(server_offline(.))) | length),
          server_expiring_count: ($nodes | map(select(server_expiring(.))) | length),
          generic_name_count: ($nodes | map(select(generic_name(.))) | length),
          warning_count: ($nodes | map(select(health(.) == "WARN")) | length),
          failing_count: ($nodes | map(select(health(.) == "FAIL")) | length)
        }'
  '';
in
{
  services.vector.settings = {
    sources = {
      headscale_logs = {
        type = "journald";
        include_units = [ "headscale.service" ];
      };

      headscale_nodes_snapshot = {
        type = "exec";
        command = [ (toString nodesSnapshotScript) ];
        mode = "scheduled";
        scheduled.exec_interval_secs = 300;
        framing.method = "newline_delimited";
        decoding.codec = "json";
      };
    };

    transforms = {
      parse_headscale = {
        type = "remap";
        inputs = [ "headscale_logs" ];
        source = ''
          raw = string!(.message)
          parsed = parse_json(raw) ?? {}

          level = "info"
          if exists(parsed.level) { level = to_string!(parsed.level) }
          msg = raw
          if exists(parsed.message) { msg = to_string!(parsed.message) }
          if exists(parsed.msg) { msg = to_string!(parsed.msg) }

          # Later matches win: prefer specific audit events over plain errors
          event = "other"
          lower = downcase(msg)
          if level == "error" { event = "error" }
          if contains(lower, "preauth") || contains(lower, "authkey") { event = "preauth_key" }
          if contains(lower, "expire") { event = "node_expire" }
          if contains(lower, "regist") { event = "node_register" }
          if contains(lower, "oidc") && (contains(lower, "denied") || contains(lower, "unauthori") || contains(lower, "not allowed") || contains(lower, "forbidden")) { event = "oidc_denied" }

          ts = .timestamp
          out = {
            "host": "${hostName}",
            "log_type": "headscale",
            "event": event,
            "level": level,
            "message": msg
          }
          if exists(parsed.node) { out.node = to_string!(parsed.node) }
          if exists(parsed.machine) { out.node = to_string!(parsed.machine) }
          if exists(parsed.user) {
            if is_object(parsed.user) && exists(parsed.user.name) { out.user = to_string!(parsed.user.name) }
            if is_string(parsed.user) { out.user = to_string!(parsed.user) }
          }

          . = out
          .timestamp = ts
        '';
      };

      filter_headscale = {
        type = "filter";
        inputs = [ "parse_headscale" ];
        condition = ".event != \"other\"";
      };
    };

    sinks = {
      headscale_audit_loki = {
        type = "loki";
        inputs = [ "filter_headscale" ];
        endpoint = lokiEndpoint;
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          log_type = "{{ log_type }}";
          event = "{{ event }}";
        };
        batch.timeout_secs = 10;
      };

      headscale_nodes_loki = {
        type = "loki";
        inputs = [ "headscale_nodes_snapshot" ];
        endpoint = lokiEndpoint;
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          log_type = "{{ log_type }}";
          event = "{{ event }}";
        };
        batch.timeout_secs = 10;
      };
    };
  };

  # The snapshot script talks to the headscale unix socket. Headscale creates
  # it owner-only, so make the socket group-readable after startup.
  systemd.services.headscale.postStart = ''
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if [ -S /run/headscale/headscale.sock ]; then
        ${lib.getExe' pkgs.coreutils "chmod"} 0770 /run/headscale/headscale.sock
        break
      fi
      ${lib.getExe' pkgs.coreutils "sleep"} 0.5
    done
  '';
  systemd.services.vector.serviceConfig.SupplementaryGroups = [ "headscale" ];
}
