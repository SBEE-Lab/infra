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
    ../modules/buildbot/edge-proxy.nix
    ../modules/uptermd
    ../modules/gatus
    ../modules/monitoring/vector
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
      domain = "docling.sjanglab.org";
      serviceName = "acme-sync-docling-to-psi";
      remoteHost = hosts.psi.wg-admin;
    }
    {
      domain = "status.sjanglab.org";
      serviceName = "acme-sync-status-to-rho";
      remoteUser = "acme-sync-status";
      remoteHost = hosts.rho.wg-admin;
    }
    {
      domain = "logging.sjanglab.org";
      serviceName = "acme-sync-logging-to-rho";
      remoteUser = "acme-sync-logging";
      remoteHost = hosts.rho.wg-admin;
    }
    {
      domain = "multievolve.sjanglab.org";
      serviceName = "acme-sync-multievolve-to-psi";
      remoteUser = "acme-sync-multievolve";
      remoteHost = hosts.psi.wg-admin;
    }
    {
      domain = "vault.sjanglab.org";
      serviceName = "acme-sync-vaultwarden-to-tau";
      remoteUser = "acme-sync-vaultwarden";
      remoteHost = hosts.tau.wg-admin;
    }
  ];

  disko.rootDisk = "/dev/vda";

  # ACME certificates for internal services
  security.acme.certs."status.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  security.acme.certs."logging.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  security.acme.certs."multievolve.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  security.acme.certs."vault.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
