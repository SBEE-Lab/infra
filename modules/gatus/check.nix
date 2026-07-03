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
  gatusApi = "http://${config.networking.sbee.hosts.eta.wg-admin}:8081";

  # Gatus external endpoint key: "${group}_${name}" with spaces/special chars → hyphens
  mkKey =
    ep:
    let
      sanitize = s: builtins.replaceStrings [ " " "/" "_" "," "." ] [ "-" "-" "-" "-" "-" ] s;
    in
    "${sanitize ep.group}_${sanitize ep.name}";

  mkUrlCheck = check: ''
    check_url ${lib.escapeShellArg check.url} ${lib.escapeShellArg (toString check.expectedStatus)}
  '';

  mkPushScript =
    ep:
    let
      checks =
        if ep.checks != null then
          ep.checks
        else if ep.url != null then
          [
            {
              inherit (ep) url expectedStatus;
            }
          ]
        else
          [ ];
    in
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
            -G \
            --data-urlencode "success=$success" \
            --data-urlencode "error=$error" \
            -H "Authorization: Bearer $GATUS_EXTERNAL_TOKEN" \
            "${gatusApi}/api/v1/endpoints/${mkKey ep}/external"
        ''
      else
        ''
          set -euo pipefail
          success=true
          error=""

          check_url() {
            local url=$1
            local expected=$2
            local status
            status=$(${pkgs.curl}/bin/curl -sf --max-time 30 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null) || true
            if [ "$status" != "$expected" ]; then
              success=false
              if [ -n "$error" ]; then
                error="$error; "
              fi
              error="''${error}$url expected $expected, got $status"
            fi
          }

          ${lib.concatMapStringsSep "" mkUrlCheck checks}
          ${pkgs.curl}/bin/curl -sf --max-time 10 \
            -X POST \
            -G \
            --data-urlencode "success=$success" \
            --data-urlencode "error=$error" \
            -H "Authorization: Bearer $GATUS_EXTERNAL_TOKEN" \
            "${gatusApi}/api/v1/endpoints/${mkKey ep}/external"
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

  urlCheckSubmodule = lib.types.submodule {
    options = {
      url = lib.mkOption { type = lib.types.str; };
      expectedStatus = lib.mkOption {
        type = lib.types.int;
        default = 200;
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
      checks = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf urlCheckSubmodule);
        default = null;
        description = "HTTP checks that must all pass before pushing success";
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
    # Validate: each push entry must have exactly one check source.
    assertions = lib.concatMap (ep: [
      {
        assertion =
          builtins.length (
            lib.filter (x: x) [
              (ep.url != null)
              (ep.checks != null)
              (ep.systemdService != null)
            ]
          ) == 1;
        message = "gatusCheck.push '${ep.name}': exactly one of 'url', 'checks', or 'systemdService' must be set";
      }
      {
        assertion = ep.checks == null || ep.checks != [ ];
        message = "gatusCheck.push '${ep.name}': checks must not be empty";
      }
    ]) cfg.push;

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
