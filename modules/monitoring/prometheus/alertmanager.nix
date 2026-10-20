{
  config,
  lib,
  ...
}:
let
  deliveryEnabled = config.services.sbee.monitoring.mode == "active";
  secretsFile = ../secrets.yaml;
  secretsText = builtins.readFile secretsFile;
  alertBridgeUrl = "https://infra-alert-bridge.sjang-bioe.workers.dev/alertmanager";
  requiredSecrets = [
    "alertmanager-bridge-token"
    "alertmanager-healthchecks-ping-url"
  ];
  hasRequiredSecrets = lib.all (name: lib.hasInfix "${name}:" secretsText) requiredSecrets;

  mkBridgeReceiver = name: {
    inherit name;
    webhook_configs = [
      {
        url = alertBridgeUrl;
        send_resolved = true;
        http_config.authorization = {
          type = "Bearer";
          credentials = "$ALERTMANAGER_WEBHOOK_TOKEN";
        };
      }
    ];
  };
in
{
  imports = [ ../../gatus/check.nix ];

  config = lib.mkMerge [
    {
      warnings = lib.optional (!hasRequiredSecrets) (
        "Alertmanager bridge delivery is disabled until modules/monitoring/secrets.yaml contains "
        + lib.concatStringsSep ", " requiredSecrets
      );
    }

    (lib.mkIf hasRequiredSecrets {
      sops = {
        secrets = {
          alertmanager-bridge-token.sopsFile = secretsFile;
          alertmanager-healthchecks-ping-url.sopsFile = secretsFile;
        };

        templates.alertmanager-env = {
          mode = "0400";
          content = ''
            ALERTMANAGER_WEBHOOK_TOKEN=${config.sops.placeholder."alertmanager-bridge-token"}
            HEALTHCHECKS_PING_URL=${config.sops.placeholder."alertmanager-healthchecks-ping-url"}
          '';
        };
      };

      gatusCheck.push = [
        {
          name = "Alertmanager";
          group = "monitoring";
          url = "http://127.0.0.1:9093/alertmanager/-/healthy";
        }
      ];

      services.prometheus = {
        alertmanagers = [
          {
            path_prefix = "/alertmanager";
            static_configs = [
              { targets = [ "127.0.0.1:9093" ]; }
            ];
          }
        ];

        alertmanager = {
          enable = true;
          # rho-local only: no remote consumer, and closing the direct
          # wg-admin port removes the unauthenticated silence-creation surface.
          # Admin access is via the Authentik-protected /alertmanager/ proxy.
          listenAddress = "127.0.0.1";
          port = 9093;
          webExternalUrl = "https://logging.sjanglab.org/alertmanager";
          checkConfig = false;
          environmentFile = config.sops.templates.alertmanager-env.path;
          configuration = {
            global = {
              resolve_timeout = "5m";
            };

            # Unclassified alerts cannot become notifications by accident.
            route = {
              receiver = "discard";
              group_by = [
                "host"
                "service"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "24h";
              routes = lib.optionals deliveryEnabled [
                {
                  matchers = [ ''alertname="Watchdog"'' ];
                  receiver = "healthchecks-deadman";
                  group_wait = "0s";
                  group_interval = "5m";
                  repeat_interval = "5m";
                }
                {
                  matchers = [ ''response="immediate"'' ];
                  receiver = "infra-alerts";
                  repeat_interval = "4h";
                }
                {
                  matchers = [ ''response="business-hours"'' ];
                  receiver = "infra-alerts";
                  active_time_intervals = [ "business-hours" ];
                }
              ];
            };

            time_intervals = [
              {
                name = "business-hours";
                time_intervals = [
                  {
                    location = "Asia/Seoul";
                    weekdays = [ "monday:friday" ];
                    times = [
                      {
                        start_time = "09:00";
                        end_time = "18:00";
                      }
                    ];
                  }
                ];
              }
            ];

            inhibit_rules = [
              {
                source_matchers = [ ''alertname="DiskSpaceCritical"'' ];
                target_matchers = [ ''alertname="DiskSpaceLow"'' ];
                equal = [
                  "host"
                  "mountpoint"
                ];
              }
              {
                source_matchers = [ ''severity="critical"'' ];
                target_matchers = [ ''severity="warning"'' ];
                equal = [
                  "alertname"
                  "host"
                  "service"
                  "mountpoint"
                ];
              }
              {
                source_matchers = [ ''alertname="HostMetricsMissing"'' ];
                target_matchers = [ ''signal="host-metrics"'' ];
                equal = [ "host" ];
              }
              {
                source_matchers = [ ''alertname="BlackboxExporterDown"'' ];
                target_matchers = [ ''signal="probe"'' ];
              }
            ];

            receivers = [
              { name = "discard"; }
            ]
            ++ lib.optionals deliveryEnabled [
              (mkBridgeReceiver "infra-alerts")
              {
                name = "healthchecks-deadman";
                webhook_configs = [
                  {
                    url = "$HEALTHCHECKS_PING_URL";
                    send_resolved = false;
                  }
                ];
              }
            ];
          };
        };
      };

    })
  ];
}
