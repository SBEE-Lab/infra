{ config, lib, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "gatus.sjanglab.org";
  port = 8081; # 8080 is used by headscale
  systemCollector = hosts.rho.wg-admin;
  cfg = config.gatusCheck;
in
{
  imports = [
    ../acme
    ./check.nix
  ];

  services.gatus = {
    enable = true;
    environmentFile = config.sops.secrets.gatus-env.path;
    settings = {
      web.port = port;
      metrics = true;

      security.basic = {
        username = "admin";
        # bcrypt hash → base64 encoded, interpolated from environmentFile
        password-bcrypt-base64 = "\${GATUS_SECURITY_BASIC_PASSWORD}";
      };

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
            alerts = [ { type = "ntfy"; } ];
          };
        in
        [
          # psi
          (mkExtEndpoint "Ollama" "ai")
          (mkExtEndpoint "Docling" "ai")
          # tau
          (mkExtEndpoint "Nextcloud" "apps")
          (mkExtEndpoint "n8n" "apps")
          # rho
          (mkExtEndpoint "Grafana" "monitoring")
          (mkExtEndpoint "Prometheus" "monitoring")
          (mkExtEndpoint "Loki" "monitoring")
          (mkExtEndpoint "PostgreSQL" "db")
        ];
    };
  };

  sops.secrets.gatus-env = {
    sopsFile = ./secrets.yaml;
  };

  # ACME certificate (DNS challenge via Cloudflare)
  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
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

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
