{ config, pkgs, ... }:
let
  domain = "cloud.sjanglab.org";
  tauWgAdmin = config.networking.sbee.hosts.tau.wg-admin;
in
{
  imports = [
    ../modules/hardware/vultr-vms.nix
    ../modules/disko/ext4-root.nix
    ../modules/ntfy.nix
    ../modules/headscale
    ../modules/authentik
    ../modules/vaultwarden
    ../modules/buildbot/reverse-proxy.nix
    ../modules/monitoring/vector
    ../modules/monitoring/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/vda";

  # Sync cloud.sjanglab.org cert to tau after ACME renewal
  security.acme.certs.${domain}.postRun = ''
    ${pkgs.systemd}/bin/systemctl start --no-block acme-sync-to-tau.service || true
  '';

  systemd.services.acme-sync-to-tau = {
    description = "Sync ${domain} certificate to tau";
    serviceConfig = {
      Type = "oneshot";
      User = "acme";
      ExecStart = pkgs.writeShellScript "sync-cert-to-tau" ''
        ${pkgs.rsync}/bin/rsync \
          -e "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.acme-sync-ssh-key.path} -p 10022 -o StrictHostKeyChecking=accept-new" \
          -avz --chmod=D750,F640 \
          /var/lib/acme/${domain}/ \
          acme-sync@${tauWgAdmin}:/var/lib/acme/${domain}/
      '';
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  sops.secrets.acme-sync-ssh-key = {
    sopsFile = ../modules/acme/secrets.yaml;
    owner = "acme";
    mode = "0400";
  };

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
