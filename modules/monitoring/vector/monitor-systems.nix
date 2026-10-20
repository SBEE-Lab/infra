# Vector collector configuration for rho
# - Local Loki sink for logs
# - Prometheus server with remote write receiver
# - Vector exporter for local metrics
{ config, lib, ... }:
let
  hosts = config.networking.sbee.hosts;
  monitoringSecretsText = builtins.readFile ../secrets.yaml;
  hasAlertmanagerSecrets = lib.all (name: lib.hasInfix "${name}:" monitoringSecretsText) [
    "alertmanager-bridge-token"
    "alertmanager-healthchecks-ping-url"
  ];

  serviceTargets = import ../targets.nix;
  httpTargets = lib.mapAttrsToList (service: target: {
    inherit service;
    inherit (target) host response;
    scope = if target.access == "public" then "public" else "tailnet";
    hostname = builtins.head (lib.splitString "/" (lib.removePrefix "https://" target.url));
    target =
      if target.access == "public" then
        target.url
      else
        lib.replaceStrings
          [ (builtins.head (lib.splitString "/" (lib.removePrefix "https://" target.url))) ]
          [ hosts.${target.probeHost or target.host}.wg-admin ]
          target.url;
  }) serviceTargets;
  blackboxHttpTargets = lib.filter (target: target.scope == "public") httpTargets;
  blackboxTailnetHttpTargets = lib.filter (target: target.scope == "tailnet") httpTargets;

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
      host = target.host or target.service;
      response = target.response or "observe";
      probe_scope = target.scope;
    };
  };

  mkBlackboxTailnetStaticConfig = target: {
    targets = [ target.target ];
    labels = {
      inherit (target)
        service
        hostname
        host
        response
        ;
      probe_scope = "tailnet";
      probe_module = if target.response == "observe" then "http_2xx_or_redirect" else "http_health";
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
      source_labels = [ "probe_module" ];
      target_label = "__param_module";
    }
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
    ../loki
    ../proxy/ingest.nix
    ../audit/ssh-access.nix
    ../audit/tailnet-app-access.nix
    ../grafana
    ../prometheus
    ../../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Prometheus";
      group = "monitoring";
      url = "http://127.0.0.1:9090/-/healthy";
    }
  ];

  # Prometheus server
  services.prometheus = {
    enable = true;
    # Query API is rho-local; remote-write ingest is re-exposed on wg-admin
    # by modules/monitoring/proxy/ingest.nix.
    listenAddress = "127.0.0.1";

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
            targets = [ "127.0.0.1:9598" ];
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
          targets = [ "127.0.0.1:9093" ];
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
        params.module = [ "http_health" ];
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
        job_name = "tei";
        scrape_interval = "30s";
        static_configs = [
          {
            targets = [ "${hosts.psi.wg-admin}:8201" ];
            labels = {
              host = "psi";
              service = "tei-embed";
              model = "Qwen/Qwen3-Embedding-0.6B";
            };
          }
          {
            targets = [ "${hosts.psi.wg-admin}:8202" ];
            labels = {
              host = "psi";
              service = "tei-rerank";
              model = "BAAI/bge-reranker-v2-m3";
            };
          }
        ];
      }
    ];
  };

  # Prometheus (9090) is re-exposed for remote-write only by
  # modules/monitoring/proxy/ingest.nix; the vector exporter (9598) has no
  # remote consumer and stays bound to localhost.

  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus2 0700 prometheus prometheus - -"
  ];
}
