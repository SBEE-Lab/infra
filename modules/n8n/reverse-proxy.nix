# n8n reverse proxy for eta
#
# Security: Only webhook endpoints are exposed to the internet.
# UI/API access is blocked (403) - use Tailscale for full access.
# Webhooks use their own authentication (URL tokens, header verification).
{ config, pkgs, ... }:
let
  inherit (config.networking.sbee) hosts;
  n8nDomain = "n8n.sjanglab.org";
in
{
  imports = [ ../acme ];

  # ACME certificate (DNS challenge via Cloudflare)
  # Also synced to tau for split DNS access
  security.acme.certs.${n8nDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
    postRun = ''
      ${pkgs.systemd}/bin/systemctl start --no-block acme-sync-n8n-to-tau.service || true
    '';
  };

  # Sync n8n cert to tau after ACME renewal
  systemd.services.acme-sync-n8n-to-tau = {
    description = "Sync ${n8nDomain} certificate to tau";
    serviceConfig = {
      Type = "oneshot";
      User = "acme";
      ExecStart = pkgs.writeShellScript "sync-n8n-cert-to-tau" ''
        ${pkgs.rsync}/bin/rsync \
          -e "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.acme-sync-ssh-key.path} -p 10022 -o StrictHostKeyChecking=accept-new" \
          -avz --chmod=D750,F640 \
          /var/lib/acme/${n8nDomain}/ \
          acme-sync-n8n@${hosts.tau.wg-admin}:/var/lib/acme/${n8nDomain}/
      '';
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  sops.secrets.acme-sync-ssh-key = {
    sopsFile = ../acme/secrets.yaml;
    owner = "acme";
    mode = "0400";
  };

  services.nginx.virtualHosts.${n8nDomain} = {
    forceSSL = true;
    useACMEHost = n8nDomain;

    # UI blocked - use Tailscale for direct access via split DNS
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
