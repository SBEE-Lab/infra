{ config, ... }:
{
  imports = [ ../acme ];

  services.headscale = {
    enable = true;
    address = "127.0.0.1";
    port = 8080;

    settings = {
      server_url = "https://hs.sjanglab.org";

      prefixes = {
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };

      dns = {
        base_domain = "sbee.lab";
        magic_dns = true;
        nameservers.global = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        extra_records = [
          {
            name = "cloud.sjanglab.org";
            type = "A";
            value = "100.64.0.3"; # tau headscale IP
          }
        ];
      };

      oidc = {
        issuer = "https://auth.sjanglab.org/application/o/headscale/";
        client_id = "4HgENmoHd0zxoqKYX6FgC2EtVKM1djT5lWEFacER";
        client_secret_path = config.sops.secrets.headscale-oidc-secret.path;
        scope = [
          "openid"
          "profile"
          "email"
        ];
        allowed_users = [
          # Add allowed email addresses here
          "lsw1167@gmail.com"
        ];
      };

      logtail.enabled = false;
      metrics_listen_addr = "127.0.0.1:9090";
    };
  };

  sops.secrets.headscale-oidc-secret = {
    sopsFile = ./secrets.yaml;
    owner = "headscale";
    group = "headscale";
    mode = "0400";
  };

  # ACME certificate
  security.acme.certs."hs.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts."hs.sjanglab.org" = {
    forceSSL = true;
    enableACME = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_buffering off;
        proxy_request_buffering off;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
