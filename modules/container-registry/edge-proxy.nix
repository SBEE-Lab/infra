# Public ingress for the zot registry and web UI, which run on psi.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "registry.sjanglab.org";
  nginxStatusPort = 9114;
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
    ../monitoring/audit/nginx-access-logs.nix
  ];

  services.sbee.nginx.edgeVhosts.${domain} = { };
  services.sbee.nginxAccessLogs.services.${domain} = "container-registry";

  acmeSyncer.mkSender = [
    {
      inherit domain;
      serviceName = "acme-sync-registry-to-psi";
      remoteUser = "acme-sync-registry";
      remoteHost = hosts.psi.wg-admin;
    }
  ];

  services.nginx = {
    recommendedTlsSettings = true;

    commonHttpConfig = ''
      limit_conn_zone $binary_remote_addr zone=container_registry_per_ip:10m;
    '';

    virtualHosts.${domain} = {
      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000" always;
        access_log /var/log/nginx/access-audit/container-registry.log nginx_access_json;
        client_header_timeout 15s;
        limit_conn container_registry_per_ip 50;
        limit_conn_status 429;
      '';

      # zot serves the registry API, its own /zot API and the UI from one origin.
      locations."/" = {
        proxyPass = "https://${hosts.psi.wg-admin}";
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name ${domain};

          client_max_body_size 50g;
          client_body_timeout 300s;
          send_timeout 300s;
          proxy_send_timeout 1800s;
          proxy_read_timeout 1800s;
          proxy_request_buffering off;
          proxy_buffering off;

          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_connect_timeout 5s;
        '';
      };
    };

    virtualHosts.nginx-status = {
      serverName = "nginx-status.internal";
      listen = [
        {
          addr = "127.0.0.1";
          port = nginxStatusPort;
        }
      ];
      locations."= /nginx_status".extraConfig = ''
        stub_status on;
        access_log off;
      '';
      locations."/".return = "404";
    };
  };

  services.prometheus.exporters.nginx = {
    enable = true;
    listenAddress = "127.0.0.1";
    scrapeUri = "http://127.0.0.1:${toString nginxStatusPort}/nginx_status";
  };

  gatusCheck.pull = [
    {
      name = "Container Registry";
      url = "https://${domain}/v2/";
      group = "storage";
      # Every repository requires a login, so a healthy registry challenges.
      conditions = [
        "[STATUS] == 401"
        "[CERTIFICATE_EXPIRATION] > 720h"
      ];
    }
  ];
}
