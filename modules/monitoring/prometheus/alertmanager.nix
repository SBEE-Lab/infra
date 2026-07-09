{
  config,
  lib,
  ...
}:
let
  secretsFile = ../secrets.yaml;
  secretsText = builtins.readFile secretsFile;
  requiredSecrets = [
    "alertmanager-slack-infra-alerts-webhook"
    "alertmanager-slack-infra-audit-webhook"
    "alertmanager-healthchecks-ping-url"
  ];
  hasRequiredSecrets = lib.all (name: lib.hasInfix "${name}:" secretsText) requiredSecrets;
in
{
  imports = [ ../../gatus/check.nix ];

  config = lib.mkMerge [
    {
      warnings = lib.optional (!hasRequiredSecrets) (
        "Alertmanager Slack delivery is disabled until modules/monitoring/secrets.yaml contains "
        + lib.concatStringsSep ", " requiredSecrets
      );
    }

    (lib.mkIf hasRequiredSecrets {
      sops.secrets.alertmanager-slack-infra-alerts-webhook = {
        sopsFile = secretsFile;
      };

      sops.secrets.alertmanager-slack-infra-audit-webhook = {
        sopsFile = secretsFile;
      };

      sops.secrets.alertmanager-healthchecks-ping-url = {
        sopsFile = secretsFile;
      };

      sops.templates.alertmanager-env = {
        mode = "0400";
        content = ''
          SLACK_INFRA_ALERTS_WEBHOOK=${config.sops.placeholder."alertmanager-slack-infra-alerts-webhook"}
          SLACK_INFRA_AUDIT_WEBHOOK=${config.sops.placeholder."alertmanager-slack-infra-audit-webhook"}
          HEALTHCHECKS_PING_URL=${config.sops.placeholder."alertmanager-healthchecks-ping-url"}
        '';
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

            route = {
              receiver = "infra-alerts";
              group_by = [
                "alertname"
                "severity"
                "host"
                "service"
                "job"
              ];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "12h";
              routes = [
                {
                  matchers = [ ''alertname="Watchdog"'' ];
                  receiver = "healthchecks-deadman";
                  group_wait = "0s";
                  group_interval = "5m";
                  repeat_interval = "5m";
                }
                {
                  matchers = [ ''alert_category="audit"'' ];
                  receiver = "infra-audit";
                  repeat_interval = "24h";
                }
                {
                  matchers = [ ''severity="critical"'' ];
                  receiver = "infra-alerts";
                  repeat_interval = "2h";
                }
              ];
            };

            inhibit_rules = [
              {
                source_matchers = [ ''alertname="HostMetricsMissing"'' ];
                target_matchers = [ ''alertname=~"DiskSpaceLow|DiskSpaceCritical|MemoryLow|HighCPULoad"'' ];
                equal = [ "host" ];
              }
              {
                source_matchers = [ ''alertname="BlackboxExporterDown"'' ];
                target_matchers = [ ''alertname="BlackboxProbeFailed"'' ];
              }
            ];

            receivers = [
              {
                name = "infra-alerts";
                slack_configs = [
                  {
                    api_url = "$SLACK_INFRA_ALERTS_WEBHOOK";
                    send_resolved = true;
                    title = "[{{ .Status | toUpper }}] {{ .CommonLabels.alertname }}";
                    text = ''
                      {{ range .Alerts }}*{{ .Labels.severity }}* {{ .Annotations.summary }}
                      {{ .Annotations.description }}
                      {{ end }}'';
                  }
                ];
              }
              {
                name = "infra-audit";
                slack_configs = [
                  {
                    api_url = "$SLACK_INFRA_AUDIT_WEBHOOK";
                    send_resolved = true;
                    title = "[{{ .Status | toUpper }}] audit: {{ .CommonLabels.alertname }}";
                    text = ''
                      {{ range .Alerts }}*{{ .Labels.severity }}* {{ .Annotations.summary }}
                      {{ .Annotations.description }}
                      {{ end }}'';
                  }
                ];
              }
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
