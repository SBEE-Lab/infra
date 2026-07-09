# Grafana dashboard server (deployed on rho)
# - Connects to Loki/Prometheus on wg-admin (internal)
# - Listens on localhost only; all access goes through the
#   Authentik-protected reverse proxy (logging.sjanglab.org)
# - Break-glass: ssh -L 3000:127.0.0.1:3000 rho, then log in as the
#   local admin account (no auth-proxy header on tunneled requests)
{ config, ... }:
let
  inherit (config.networking.sbee) currentHost;
  wgAdminAddr = currentHost.wg-admin;

  lokiUrl = "http://${wgAdminAddr}:3100";
  prometheusUrl = "http://${wgAdminAddr}:9090";
in
{
  imports = [
    ./dashboards
    ../../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Grafana";
      group = "monitoring";
      checks = [
        { url = "http://127.0.0.1:3000/api/health"; }
        {
          url = "https://logging.sjanglab.org/";
          expectedStatus = 302;
        }
      ];
    }
  ];

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
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
        auto_assign_org_role = "Viewer";
        default_theme = "system";
      };

      # Identity comes from Authentik forward auth via the local nginx
      # reverse proxy only. The localhost bind plus whitelist below are
      # load-bearing: without both, any peer able to reach Grafana could
      # spoof X-authentik-email and impersonate users.
      "auth.proxy" = {
        enabled = true;
        header_name = "X-authentik-email";
        header_property = "email";
        auto_sign_up = true;
        whitelist = "127.0.0.1";
      };
    };

    provision = {
      enable = true;

      datasources.settings.datasources = [
        {
          name = "Prometheus";
          uid = "PBFA97CFB590B2093";
          type = "prometheus";
          url = prometheusUrl;
          isDefault = true;
          editable = false;
        }
        {
          name = "Loki";
          uid = "P8E80F9AEF21F6940";
          type = "loki";
          url = lokiUrl;
          editable = false;
        }
      ];
    };
  };

  assertions = [
    {
      assertion =
        let
          settings = config.services.grafana.settings;
          authProxy = settings."auth.proxy" or { };
        in
        !(authProxy.enabled or false)
        || (settings.server.http_addr == "127.0.0.1" && (authProxy.whitelist or "") == "127.0.0.1");
      message = ''
        Grafana auth.proxy trusts the X-authentik-email header unconditionally.
        It must only be enabled with server.http_addr = "127.0.0.1" and
        auth.proxy.whitelist = "127.0.0.1", otherwise wg-admin peers can spoof
        the header and impersonate any user.
      '';
    }
  ];

  sops.secrets.grafana-admin-password = {
    sopsFile = ../secrets.yaml;
    owner = "grafana";
    group = "grafana";
  };

  sops.secrets.grafana-secret-key = {
    sopsFile = ../secrets.yaml;
    owner = "grafana";
    group = "grafana";
  };

}
