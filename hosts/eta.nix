{ config, pkgs, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sjanglab.org";
  ollamaDomain = "ollama.sjanglab.org";
  doclingDomain = "docling.sjanglab.org";
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
    ../modules/n8n/reverse-proxy.nix
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
          acme-sync@${hosts.tau.wg-admin}:/var/lib/acme/${domain}/
      '';
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # ACME certificate for ollama.sjanglab.org (internal only)
  security.acme.certs.${ollamaDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
    postRun = ''
      ${pkgs.systemd}/bin/systemctl start --no-block acme-sync-ollama-to-psi.service || true
    '';
  };

  # Sync ollama.sjanglab.org cert to psi after ACME renewal
  systemd.services.acme-sync-ollama-to-psi = {
    description = "Sync ${ollamaDomain} certificate to psi";
    serviceConfig = {
      Type = "oneshot";
      User = "acme";
      ExecStart = pkgs.writeShellScript "sync-ollama-cert-to-psi" ''
        ${pkgs.rsync}/bin/rsync \
          -e "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.acme-sync-ssh-key.path} -p 10022 -o StrictHostKeyChecking=accept-new" \
          -avz --chmod=D750,F640 \
          /var/lib/acme/${ollamaDomain}/ \
          acme-sync-ollama@${hosts.psi.wg-admin}:/var/lib/acme/${ollamaDomain}/
      '';
    };
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # Sync docling cert to psi after ACME renewal
  security.acme.certs.${doclingDomain}.postRun = ''
    ${pkgs.systemd}/bin/systemctl start --no-block acme-sync-docling-to-psi.service || true
  '';

  # Sync docling.sjanglab.org cert to psi after ACME renewal
  systemd.services.acme-sync-docling-to-psi = {
    description = "Sync ${doclingDomain} certificate to psi";
    serviceConfig = {
      Type = "oneshot";
      User = "acme";
      ExecStart = pkgs.writeShellScript "sync-docling-cert-to-psi" ''
        ${pkgs.rsync}/bin/rsync \
          -e "${pkgs.openssh}/bin/ssh -i ${config.sops.secrets.acme-sync-ssh-key.path} -p 10022 -o StrictHostKeyChecking=accept-new" \
          -avz --chmod=D750,F640 \
          /var/lib/acme/${doclingDomain}/ \
          acme-sync@${hosts.psi.wg-admin}:/var/lib/acme/${doclingDomain}/
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
