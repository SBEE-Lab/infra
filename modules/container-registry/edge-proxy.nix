# Public Docker/OCI Registry and token-auth endpoint on eta.
{
  config,
  containerRegistry,
  ...
}:
let
  nginxStatusPort = 9114;

  proxyHeaders = ''
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 5s;
  '';

  authLocation = {
    proxyPass = "http://${containerRegistry.auth.address}:${toString containerRegistry.auth.port}";
    extraConfig = ''
      client_max_body_size 64k;
      client_body_timeout 10s;
      send_timeout 30s;
      proxy_send_timeout 30s;
      proxy_read_timeout 30s;

      limit_req zone=container_registry_auth burst=40 nodelay;
      limit_req zone=container_registry_basic_auth burst=10 nodelay;
      limit_req_status 429;
      limit_conn container_registry_per_ip 10;
      limit_conn_status 429;

      limit_except GET POST {
        deny all;
      }

      ${proxyHeaders}
    '';
  };
in
{
  imports = [
    ../acme
    ../monitoring/nginx-access-logs.nix
  ];

  services.sbee.nginxAccessLogs.services.${containerRegistry.domain} = "container-registry";

  services.nginx = {
    recommendedTlsSettings = true;

    commonHttpConfig = ''
      map $http_authorization $container_registry_basic_auth_client {
        default "";
        ~*^Basic\s+ $binary_remote_addr;
      }

      limit_req_zone $binary_remote_addr zone=container_registry_auth:10m rate=20r/s;
      limit_req_zone $container_registry_basic_auth_client zone=container_registry_basic_auth:10m rate=1r/s;
      limit_conn_zone $binary_remote_addr zone=container_registry_per_ip:10m;
    '';

    virtualHosts.${containerRegistry.domain} = {
      forceSSL = true;
      useACMEHost = containerRegistry.domain;

      extraConfig = ''
        add_header Strict-Transport-Security "max-age=31536000" always;
        access_log /var/log/nginx/access-audit/container-registry.log nginx_access_json;
        client_header_timeout 15s;
        limit_conn container_registry_per_ip 50;
        limit_conn_status 429;
      '';

      locations."= /v2".return = "308 /v2/";

      locations."/v2/" = {
        proxyPass = "http://${containerRegistry.registry.address}:${toString containerRegistry.registry.port}";
        extraConfig = ''
          client_max_body_size 50g;
          client_body_timeout 300s;
          send_timeout 300s;
          proxy_send_timeout 1800s;
          proxy_read_timeout 1800s;
          proxy_request_buffering off;
          proxy_buffering off;

          ${proxyHeaders}
        '';
      };

      # docker_auth exposes both Distribution and OAuth-compatible token paths.
      locations."= /auth" = authLocation;
      locations."= /auth/token" = authLocation;
      locations."/".return = "404";
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

  security.acme.certs.${containerRegistry.domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };
}
