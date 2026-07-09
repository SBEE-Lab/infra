# Tailscale client module for connecting to self-hosted Headscale
#
# Usage:
# 1. Generate pre-auth key on Headscale server:
#    headscale preauthkeys create --user servers --expiration 87600h --reusable
# 2. Add key to hosts/<hostname>.yaml as tailscale-authkey
# 3. Import this module
{
  config,
  ...
}:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale-authkey.path;
    extraUpFlags = [
      "--login-server=https://hs.sjanglab.org"
      "--advertise-tags=tag:server"
    ];
  };

  sops.secrets.tailscale-authkey = {
    sopsFile = ./secrets.yaml;
  };

  # Explicit port allowlist for Headscale users (no trustedInterfaces)
  # - 80, 443: Web services (Nextcloud on tau)
  # - 8010: Nixbot (psi, disabled when nginx uses unix socket)
  # SSH and internal services remain wg-admin only; Grafana is reachable
  # solely through the Authentik-protected reverse proxy on 443.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    80
    443
    8010
  ];
}
