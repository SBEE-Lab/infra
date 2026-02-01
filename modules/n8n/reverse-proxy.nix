# n8n reverse proxy for eta
#
# Security: Only webhook endpoints are exposed to the internet.
# UI/API access is blocked (403) - use Tailscale for full access.
# Webhooks use their own authentication (URL tokens, header verification).
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  n8nDomain = "n8n.sjanglab.org";
in
{
  imports = [ ../acme ];

  # ACME certificate (DNS challenge via Cloudflare)
  security.acme.certs.${n8nDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  services.nginx.virtualHosts.${n8nDomain} = {
    forceSSL = true;
    useACMEHost = n8nDomain;

    # Default: deny all (UI, API, etc.)
    locations."/" = {
      return = "403";
    };

    # Webhook endpoints - these use their own authentication mechanisms
    locations."~ ^/webhook(-test)?/" = {
      proxyPass = "http://${hosts.tau.wg-admin}:5678";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Webhook timeouts (some webhooks may take time)
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;

        # Request size for webhook payloads
        client_max_body_size 16M;
      '';
    };

    # Health check endpoint for monitoring
    locations."= /healthz" = {
      proxyPass = "http://${hosts.tau.wg-admin}:5678";
      extraConfig = ''
        proxy_set_header Host $host;
      '';
    };
  };
}
