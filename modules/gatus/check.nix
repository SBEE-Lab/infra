# Gatus health check registration module
#
# Pull (Gatus server polls the URL directly from eta):
#   gatusCheck.pull = [
#     { name = "Authentik"; url = "https://auth.sjanglab.org"; group = "auth"; }
#   ];
#
# Push (host checks localhost, pushes result to Gatus external endpoint API):
#   gatusCheck.push = [
#     { name = "Ollama"; group = "ai"; url = "http://127.0.0.1:11434"; }
#     { name = "borgbackup"; group = "backup"; systemdService = "borgbackup-job-main.service"; }
#   ];
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gatusCheck;
  gatusApi = "https://gatus.sjanglab.org";

  # Gatus external endpoint key: "${group}_${name}" with spaces/special chars → hyphens
  mkKey =
    ep:
    let
      sanitize = s: builtins.replaceStrings [ " " "/" "_" "," "." ] [ "-" "-" "-" "-" "-" ] s;
    in
    "${sanitize ep.group}_${sanitize ep.name}";

  mkPushScript =
    ep:
    pkgs.writeShellScript "gatus-push-${mkKey ep}" (
      if ep.systemdService != null then
        ''
          set -euo pipefail
          if ${pkgs.systemd}/bin/systemctl is-active --quiet ${ep.systemdService}; then
            success=true
            error=""
          else
            success=false
            error="$(${pkgs.systemd}/bin/systemctl show -p SubState --value ${ep.systemdService})"
          fi
          ${pkgs.curl}/bin/curl -sf --max-time 10 \
            -X POST \
            -H "Authorization: Bearer $GATUS_EXTERNAL_TOKEN" \
            "${gatusApi}/api/v1/endpoints/${mkKey ep}/external?success=$success&error=$error"
        ''
      else
        ''
          set -euo pipefail
          status=$(${pkgs.curl}/bin/curl -sf --max-time 30 -o /dev/null -w "%{http_code}" "${ep.url}" 2>/dev/null) || true
          if [ "$status" = "${toString ep.expectedStatus}" ]; then
            success=true
            error=""
          else
            success=false
            error="expected ${toString ep.expectedStatus}, got $status"
          fi
          ${pkgs.curl}/bin/curl -sf --max-time 10 \
            -X POST \
            -H "Authorization: Bearer $GATUS_EXTERNAL_TOKEN" \
            "${gatusApi}/api/v1/endpoints/${mkKey ep}/external?success=$success&error=$error"
        ''
    );

  pullSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      url = lib.mkOption { type = lib.types.str; };
      group = lib.mkOption { type = lib.types.str; };
      interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
      };
      conditions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "[STATUS] == 200"
          "[CERTIFICATE_EXPIRATION] > 720h"
        ];
      };
    };
  };

  pushSubmodule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      group = lib.mkOption { type = lib.types.str; };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      expectedStatus = lib.mkOption {
        type = lib.types.int;
        default = 200;
      };
      systemdService = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      interval = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Check interval in seconds";
      };
    };
  };
in
{
  options.gatusCheck = {
    pull = lib.mkOption {
      type = lib.types.listOf pullSubmodule;
      default = [ ];
      description = "Endpoints that Gatus polls directly (must be reachable from eta)";
    };
    push = lib.mkOption {
      type = lib.types.listOf pushSubmodule;
      default = [ ];
      description = "Endpoints checked locally and pushed to Gatus external endpoint API";
    };
  };

  # Push: systemd timers on the declaring host
  config = lib.mkIf (cfg.push != [ ]) {
    # Validate: each push entry must have exactly one of url or systemdService
    assertions = map (ep: {
      assertion = (ep.url != null) != (ep.systemdService != null);
      message = "gatusCheck.push '${ep.name}': exactly one of 'url' or 'systemdService' must be set";
    }) cfg.push;

    # Resolve gatus.sjanglab.org → eta WG IP for hosts behind NAT/WG
    networking.hosts.${config.networking.sbee.hosts.eta.wg-admin} = [ "gatus.sjanglab.org" ];

    sops.secrets.gatus-push-token = {
      sopsFile = ./secrets.yaml;
    };

    systemd.services = builtins.listToAttrs (
      map (
        ep:
        lib.nameValuePair "gatus-push-${mkKey ep}" {
          description = "Push health check: ${ep.name}";
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.secrets.gatus-push-token.path;
            ExecStart = mkPushScript ep;
          };
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
        }
      ) cfg.push
    );

    systemd.timers = builtins.listToAttrs (
      map (
        ep:
        lib.nameValuePair "gatus-push-${mkKey ep}" {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "${toString ep.interval}s";
            RandomizedDelaySec = "30s";
          };
        }
      ) cfg.push
    );
  };

  # Pull: consumed by gatus/default.nix via config.gatusCheck.pull
  # (no config generated here — the Gatus server reads it)
}
