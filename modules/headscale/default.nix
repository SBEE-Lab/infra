{ config, ... }:
{
  imports = [
    ../acme
    ../gatus/check.nix
    ./tag-sync.nix
    ./audit.nix
  ];

  gatusCheck.pull = [
    {
      name = "Headscale";
      url = "https://hs.sjanglab.org/health";
      group = "platform";
    }
  ];

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
        # Route sjanglab.org queries to MagicDNS (Split DNS)
        search_domains = [ "sjanglab.org" ];
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
          {
            name = "n8n.sjanglab.org";
            type = "A";
            value = "100.64.0.3"; # tau headscale IP
          }
          {
            name = "docling.sjanglab.org";
            type = "A";
            value = "100.64.0.1"; # psi headscale IP
          }
          {
            name = "tei.sjanglab.org";
            type = "A";
            value = "100.64.0.1"; # psi headscale IP
          }
          {
            name = "status.sjanglab.org";
            type = "A";
            value = "100.64.0.2"; # rho headscale IP
          }
          {
            name = "logging.sjanglab.org";
            type = "A";
            value = "100.64.0.2"; # rho headscale IP
          }
          {
            name = "multievolve.sjanglab.org";
            type = "A";
            value = "100.64.0.1"; # psi headscale IP
          }
          {
            name = "vault.sjanglab.org";
            type = "A";
            value = "100.64.0.3"; # tau headscale IP
          }
          {
            name = "omnigraph.sjanglab.org";
            type = "A";
            value = "100.64.0.3"; # tau headscale IP
          }
          {
            name = "upterm.sjanglab.org";
            type = "A";
            value = "141.164.53.203"; # eta public IP
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
          "groups"
        ];
        # Group-based access control via Authentik
        allowed_groups = [
          "sjanglab-admins"
          "sjanglab-researchers"
          "sjanglab-students"
        ];
      };

      logtail.enabled = false;
      metrics_listen_addr = "127.0.0.1:9090";

      # JSON logs so Vector can classify audit events reliably (audit.nix)
      log.format = "json";

      # ACL policy is managed by terraform/headscale through the Headscale API.
      policy.mode = "database";
    };
  };

  sops.secrets.headscale-oidc-secret = {
    sopsFile = ../../terraform/authentik/oidc-secrets.yaml;
    key = "HEADSCALE_CLIENT_SECRET";
    owner = "headscale";
    group = "headscale";
    mode = "0400";
    restartUnits = [ "headscale.service" ];
  };

  # ACME certificate
  security.acme.certs."hs.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts."hs.sjanglab.org" = {
    forceSSL = true;
    useACMEHost = "hs.sjanglab.org";

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
