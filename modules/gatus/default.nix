{ config, lib, ... }:
let
  inherit (config.networking.sbee) hosts;
  port = 8081; # 8080 is used by headscale
  systemCollector = hosts.rho.wg-admin;
  cfg = config.gatusCheck;
in
{
  imports = [ ./check.nix ];

  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus-env.path;
    settings = {
      web = {
        address = "0.0.0.0";
        inherit port;
      };
      metrics = true;

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/gatus.sqlite";
        caching = true;
        maximum-number-of-results = 720;
        maximum-number-of-events = 200;
      };

      ui.default-sort-by = "group";

      alerting.ntfy = {
        topic = "gatus";
        url = "https://ntfy.sjanglab.org";
        priority = 3;
        default-alert = {
          failure-threshold = 3;
          success-threshold = 2;
          send-on-resolved = true;
        };
      };

      # Consumed from gatusCheck.pull declared by service modules
      endpoints = map (ep: {
        inherit (ep)
          name
          url
          group
          interval
          conditions
          ;
        alerts = [ { type = "ntfy"; } ];
      }) cfg.pull;

      # External endpoints: each remote host pushes its own health status
      # Cannot be auto-collected from gatusCheck.push (cross-host boundary)
      # Token interpolated from environmentFile at runtime
      external-endpoints =
        let
          mkExtEndpoint = name: group: {
            inherit name group;
            token = "\${GATUS_EXTERNAL_TOKEN}";
            heartbeat.interval = "15m";
            alerts = [ { type = "ntfy"; } ];
          };
        in
        [
          # psi
          (mkExtEndpoint "Nixbot" "ci")
          (mkExtEndpoint "Docling" "apps")
          (mkExtEndpoint "MULTI-evolve" "apps")
          # tau
          (mkExtEndpoint "Nextcloud" "apps")
          (mkExtEndpoint "n8n" "apps")
          (mkExtEndpoint "Vaultwarden" "apps")
          # rho
          (mkExtEndpoint "Grafana" "monitoring")
          (mkExtEndpoint "Prometheus" "monitoring")
          (mkExtEndpoint "Loki" "monitoring")
          (mkExtEndpoint "PostgreSQL" "platform")
        ];
    };
  };

  sops.secrets.gatus-env = {
    sopsFile = ./secrets.yaml;
  };

  # Vector: scrape Gatus /metrics → push to rho Prometheus
  # Independent source+sink pair, does not interfere with existing Vector pipeline
  services.vector.settings = {
    sources.gatus_metrics = {
      type = "prometheus_scrape";
      endpoints = [ "http://127.0.0.1:${toString port}/metrics" ];
      scrape_interval_secs = 60;
    };
    sinks.gatus_metrics_remote = lib.mkIf (config.networking.hostName != "rho") {
      type = "prometheus_remote_write";
      inputs = [ "gatus_metrics" ];
      endpoint = "http://${systemCollector}:9090/api/v1/write";
      batch.timeout_secs = 10;
      healthcheck.enabled = false;
    };
  };

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ port ];
}
