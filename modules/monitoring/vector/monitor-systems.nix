# Vector collector configuration for rho
# - Local Loki sink for logs
# - Prometheus server with remote write receiver
# - Vector exporter for local metrics
{ config, lib, ... }:
let
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
  hosts = config.networking.sbee.hosts;
  monitoringSecretsText = builtins.readFile ../secrets.yaml;
  hasAlertmanagerSecrets = lib.all (name: lib.hasInfix "${name}:" monitoringSecretsText) [
    "alertmanager-slack-infra-alerts-webhook"
    "alertmanager-slack-infra-audit-webhook"
    "alertmanager-healthchecks-ping-url"
  ];

  blackboxHttpTargets = [
    {
      service = "authentik";
      scope = "public";
      target = "https://auth.sjanglab.org";
    }
    {
      service = "headscale";
      scope = "public";
      target = "https://hs.sjanglab.org/health";
    }
    {
      service = "n8n";
      scope = "public";
      target = "https://n8n.sjanglab.org/healthz";
    }
  ];

  blackboxTailnetHttpTargets = [
    {
      service = "gatus";
      target = "https://${hosts.rho.wg-admin}/";
      hostname = "status.sjanglab.org";
    }
    {
      service = "grafana";
      target = "https://${hosts.rho.wg-admin}/";
      hostname = "logging.sjanglab.org";
    }
    {
      service = "n8n-ui";
      target = "https://${hosts.tau.wg-admin}/";
      hostname = "n8n.sjanglab.org";
    }
    {
      service = "nextcloud";
      target = "https://${hosts.tau.wg-admin}/status.php";
      hostname = "cloud.sjanglab.org";
    }
    {
      service = "vaultwarden";
      target = "https://${hosts.tau.wg-admin}/alive";
      hostname = "vault.sjanglab.org";
    }
    {
      service = "docling";
      target = "https://${hosts.psi.wg-admin}/health";
      hostname = "docling.sjanglab.org";
    }
    {
      service = "multievolve";
      target = "https://${hosts.psi.wg-admin}/";
      hostname = "multievolve.sjanglab.org";
    }
  ];

  blackboxTcpTargets = [
    {
      service = "upterm";
      scope = "public";
      target = "upterm.sjanglab.org:2323";
    }
  ];

  blackboxIcmpTargets = builtins.map (host: {
    service = host;
    scope = "wg-admin";
    target = hosts.${host}.wg-admin;
  }) (builtins.attrNames hosts);

  mkBlackboxStaticConfig = target: {
    targets = [ target.target ];
    labels = {
      inherit (target) service;
      probe_scope = target.scope;
    };
  };

  mkBlackboxTailnetStaticConfig = target: {
    targets = [ target.target ];
    labels = {
      inherit (target) service hostname;
      probe_scope = "tailnet";
    };
  };

  blackboxRelabelConfigs = [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "__param_target" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = "${hosts.eta.wg-admin}:9115";
    }
  ];

  blackboxTailnetRelabelConfigs = [
    {
      source_labels = [ "__address__" ];
      target_label = "__param_target";
    }
    {
      source_labels = [ "hostname" ];
      target_label = "__param_hostname";
    }
    {
      source_labels = [ "hostname" ];
      target_label = "instance";
    }
    {
      target_label = "__address__";
      replacement = "${hosts.eta.wg-admin}:9115";
    }
  ];
in
{
  imports = [
    ./default.nix
    ../loki.nix
    ../grafana
    ../prometheus
    ../../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Prometheus";
      group = "monitoring";
      url = "http://${wgAdminAddr}:9090/-/healthy";
    }
  ];

  services.vector.settings.sinks = {
    # SSH logs to local Loki
    ssh_logs_local = {
      type = "loki";
      inputs = [ "filter_ssh" ];
      endpoint = "http://${wgAdminAddr}:3100";
      encoding.codec = "json";
      labels = {
        host = "{{ host }}";
        log_type = "{{ log_type }}";
        event = "{{ event }}";
      };
    };

    # Audit logs to local Loki
    audit_logs_local = {
      type = "loki";
      inputs = [ "filter_audit" ];
      endpoint = "http://${wgAdminAddr}:3100";
      encoding.codec = "json";
      labels = {
        host = "{{ host }}";
        log_type = "{{ log_type }}";
        event = "{{ event }}";
      };
    };

    system_metrics_local = {
      type = "prometheus_exporter";
      inputs = [ "tag_metrics" ];
      address = "${wgAdminAddr}:9598";
    };
  };

  # Prometheus server
  services.prometheus = {
    enable = true;
    listenAddress = wgAdminAddr;

    # Alertmanager generator URLs must be reachable from browsers, so point
    # them at the authenticated reverse proxy instead of the wg-admin address.
    webExternalUrl = "https://logging.sjanglab.org/prometheus";

    # enable remote write receiver
    extraFlags = [
      "--web.enable-remote-write-receiver"
      "--storage.tsdb.retention.time=30d"
      # Keep internal API paths stable for Grafana and remote-write while source
      # links point at the authenticated reverse proxy path.
      "--web.route-prefix=/"
    ];

    scrapeConfigs = [
      {
        job_name = "vector";
        scrape_interval = "60s";
        static_configs = [
          {
            targets = [ "${wgAdminAddr}:9598" ];
          }
        ];
      }
      {
        job_name = "blackbox_exporter";
        scrape_interval = "60s";
        static_configs = [
          {
            targets = [ "${hosts.eta.wg-admin}:9115" ];
            labels.host = "eta";
          }
        ];
      }
    ]
    ++ lib.optional hasAlertmanagerSecrets {
      job_name = "alertmanager";
      metrics_path = "/alertmanager/metrics";
      scrape_interval = "60s";
      static_configs = [
        {
          targets = [ "${wgAdminAddr}:9093" ];
          labels.host = "rho";
        }
      ];
    }
    ++ [
      {
        job_name = "blackbox_http";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        scrape_interval = "60s";
        static_configs = builtins.map mkBlackboxStaticConfig blackboxHttpTargets;
        relabel_configs = blackboxRelabelConfigs;
      }
      {
        job_name = "blackbox_tailnet_http";
        metrics_path = "/probe";
        params.module = [ "http_2xx_or_redirect" ];
        scrape_interval = "60s";
        static_configs = builtins.map mkBlackboxTailnetStaticConfig blackboxTailnetHttpTargets;
        relabel_configs = blackboxTailnetRelabelConfigs;
      }
      {
        job_name = "blackbox_tcp";
        metrics_path = "/probe";
        params.module = [ "tcp_connect" ];
        scrape_interval = "60s";
        static_configs = builtins.map mkBlackboxStaticConfig blackboxTcpTargets;
        relabel_configs = blackboxRelabelConfigs;
      }
      {
        job_name = "blackbox_icmp";
        metrics_path = "/probe";
        params.module = [ "icmp" ];
        scrape_interval = "60s";
        static_configs = builtins.map mkBlackboxStaticConfig blackboxIcmpTargets;
        relabel_configs = blackboxRelabelConfigs;
      }
      {
        job_name = "nvidia-gpu";
        scrape_interval = "30s";
        static_configs = [
          {
            targets = [ "${hosts.psi.wg-admin}:9835" ];
            labels.host = "psi";
          }
        ];
      }
      {
        job_name = "restic";
        scrape_interval = "5m";
        static_configs = [
          {
            targets = [ "${hosts.psi.wg-admin}:9753" ];
            labels = {
              host = "psi";
              repository = "psi-protected";
            };
          }
        ];
      }
    ];
  };

  networking.firewall.interfaces."wg-admin".allowedTCPPorts = [
    9090 # Prometheus
    9598 # Vector exporter
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus2 0700 prometheus prometheus - -"
  ];
}
