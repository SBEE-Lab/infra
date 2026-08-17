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

  # Explicit port allowlist for Headscale users (no trustedInterfaces).
  # Network ACLs control reachability; OpenSSH still authenticates POSIX users
  # and enforces host-local login policy on port 10022.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    80
    443
    8010
    10022
  ];
}
