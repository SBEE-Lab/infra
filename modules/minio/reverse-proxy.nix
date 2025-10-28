{
  config,
  lib,
  ...
}: let
  inherit (config.networking.sbee) hosts;
  cfg = config.services.minio;
  acmeDomains = ["minio.sjanglab.org" "s3.sjanglab.org"];
in {
  imports = [../acme];

  services.nginx = {
    commonHttpConfig = ''
      add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains; preload' always;
    '';

    upstreams = {
      "minio-console".extraConfig = ''
        server ${hosts.rho.wg-serv}${cfg.consoleAddress};
        keepalive 32;
        keepalive_timeout 60s;
      '';
      "minio-api".extraConfig = ''
        server ${hosts.rho.wg-serv}${cfg.listenAddress};
        keepalive 32;
        keepalive_timeout 60s;
      '';
    };

    virtualHosts."minio.sjanglab.org" = {
      forceSSL = true;
      enableACME = true;

      locations."/" = {
        proxyPass = "http://minio-console";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_connect_timeout 60s;
          proxy_read_timeout 60s;
          proxy_send_timeout 60s;
        '';
      };

      locations."/ws" = {
        proxyPass = "http://minio-console";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };
    };

    virtualHosts."s3.sjanglab.org" = {
      forceSSL = true;
      enableACME = true;
      locations."/".proxyPass = "http://minio-api";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  security.acme.certs = lib.genAttrs acmeDomains (_domain: {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
  });
}
