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
      "--login-server"
      "https://hs.sjanglab.org"
    ];
  };

  sops.secrets.tailscale-authkey = {
    sopsFile = ./secrets.yaml;
  };

  # Allow Tailscale traffic
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
