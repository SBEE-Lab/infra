# Vector collector configuration for rho
# - Local Loki sink for logs
# - Prometheus server with remote write receiver
# - Vector exporter for local metrics
{ config, ... }:
let
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
in
{
  imports = [
    ./default.nix
    ../loki.nix
    ../grafana.nix
    ../prometheus
  ];

  services.vector.settings.sinks = {
    # SSH logs to local Loki
    ssh_logs_local = {
      type = "loki";
      inputs = [ "filter_ssh" ];
      endpoint = "http://127.0.0.1:3100";
      encoding.codec = "json";
      labels = {
        host = "{{ host }}";
        log_type = "{{ log_type }}";
        event = "{{ event }}";
        user = "{{ user }}";
      };
    };

    # Audit logs to local Loki
    audit_logs_local = {
      type = "loki";
      inputs = [ "filter_audit" ];
      endpoint = "http://127.0.0.1:3100";
      encoding.codec = "json";
      labels = {
        host = "{{ host }}";
        log_type = "{{ log_type }}";
        event = "{{ event }}";
        user = "{{ user }}";
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

    # enable remote write receiver
    extraFlags = [
      "--web.enable-remote-write-receiver"
      "--storage.tsdb.retention.time=30d"
    ];

    # scrab local vector metric
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
