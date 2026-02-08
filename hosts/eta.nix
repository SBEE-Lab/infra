{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
in
{
  imports = [
    ../modules/hardware/vultr-vms.nix
    ../modules/disko/ext4-root.nix
    ../modules/ntfy.nix
    ../modules/headscale
    ../modules/authentik
    ../modules/vaultwarden
    ../modules/gatus
    ../modules/buildbot/reverse-proxy.nix
    ../modules/monitoring/vector
    ../modules/monitoring/reverse-proxy.nix
    ../modules/n8n/reverse-proxy.nix
    ../modules/acme/sync.nix
  ];

  acmeSyncer.mkSender = [
    {
      domain = "cloud.sjanglab.org";
      serviceName = "acme-sync-to-tau";
      remoteHost = hosts.tau.wg-admin;
    }
    {
      domain = "ollama.sjanglab.org";
      serviceName = "acme-sync-ollama-to-psi";
      remoteUser = "acme-sync-ollama";
      remoteHost = hosts.psi.wg-admin;
    }
    {
      domain = "docling.sjanglab.org";
      serviceName = "acme-sync-docling-to-psi";
      remoteHost = hosts.psi.wg-admin;
    }
    {
      domain = "tei.sjanglab.org";
      serviceName = "acme-sync-tei-to-psi";
      remoteHost = hosts.psi.wg-admin;
    }
  ];

  disko.rootDisk = "/dev/vda";

  # ACME certificate for ollama.sjanglab.org (internal only)
  security.acme.certs."ollama.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
