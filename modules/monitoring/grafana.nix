# Grafana dashboard server (deployed on rho)
# - Listens on wg-admin for access
# - Connects to Loki/Prometheus on wg-admin (internal)
{ config, ... }:
let
  inherit (config.networking.sbee) currentHost;
  wgAdminAddr = currentHost.wg-admin;

  lokiUrl = "http://${wgAdminAddr}:3100";
  prometheusUrl = "http://${wgAdminAddr}:9090";
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "Grafana";
      group = "monitoring";
      url = "http://127.0.0.1:3000/api/health";
    }
  ];

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = wgAdminAddr;
        http_port = 3000;
        domain = "logging.sjanglab.org";
        root_url = "https://logging.sjanglab.org";
      };

      analytics.reporting_enabled = false;

      security = {
        admin_user = "admin";
        admin_password = "$__file{${config.sops.secrets.grafana-admin-password.path}}";
        secret_key = "$__file{${config.sops.secrets.grafana-secret-key.path}}";
      };

      users = {
        allow_sign_up = false;
        default_theme = "system";
      };

      # Anonymous read-only access: intentional for wg-admin peers.
      # Grafana only listens on wg-admin, so only WG-authenticated hosts can reach it.
      "auth.anonymous" = {
        enabled = true;
        org_name = "Public";
        org_role = "Viewer";
      };
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = prometheusUrl;
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          type = "loki";
          url = lokiUrl;
          editable = false;
        }
      ];
    };
  };

  sops.secrets.grafana-admin-password = {
    sopsFile = ./secrets.yaml;
    owner = "grafana";
    group = "grafana";
  };

  sops.secrets.grafana-secret-key = {
    sopsFile = ./secrets.yaml;
    owner = "grafana";
    group = "grafana";
  };

  networking.firewall.interfaces."wg-admin".allowedTCPPorts = [ 3000 ];
}
