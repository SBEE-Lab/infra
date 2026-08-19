{ config, ... }:
{
  networking.naru.ed25519PrivateKeyFile = config.sops.secrets.tinc-naru-key.path;

  sops.secrets.tinc-naru-key = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.tincr.networks.naru.extraConfig = "StrictSubnets = yes";

  networking.firewall.interfaces."tinc.naru".allowedTCPPorts = config.services.openssh.ports;
}
