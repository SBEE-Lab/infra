{ config, ... }:
let
  policyPath = "/var/lib/headscale/policy.json";
in
{
  imports = [
    ../acme
    ../gatus/check.nix
    ./acl-sync.nix
    ./tag-sync.nix
  ];

  gatusCheck.pull = [
    {
      name = "Headscale";
      url = "https://hs.sjanglab.org/health";
      group = "auth";
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
            name = "ollama.sjanglab.org";
            type = "A";
            value = "100.64.0.1"; # psi headscale IP
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
            name = "vllm.sjanglab.org";
            type = "A";
            value = "100.64.0.1"; # psi headscale IP
          }
          {
            name = "rag.sjanglab.org";
            type = "A";
            value = "100.64.0.2"; # rho headscale IP
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

      # ACL policy: static rules + dynamic groups from Authentik (see acl-sync.nix)
      policy = {
        mode = "file";
        path = policyPath;
      };
    };
  };

  sops.secrets.headscale-oidc-secret = {
    sopsFile = ./secrets.yaml;
    owner = "headscale";
    group = "headscale";
    mode = "0400";
  };

  # Fallback policy for initial boot (before first acl-sync run)
  # Uses permissive rules; acl-sync overwrites with group-based ACLs
  systemd.tmpfiles.rules =
    let
      fallback = builtins.toJSON {
        groups = { };
        acls = [
          {
            action = "accept";
            src = [ "autogroup:member" ];
            dst = [ "*:*" ];
          }
        ];
        ssh = [ ];
      };
    in
    [ "f ${policyPath} 0640 headscale headscale - ${fallback}" ];

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
