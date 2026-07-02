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
      domain = "gatus.sjanglab.org";
      serviceName = "acme-sync-gatus-to-rho";
      remoteUser = "acme-sync-gatus";
      remoteHost = hosts.rho.wg-admin;
    }
    {
      domain = "logging.sjanglab.org";
      serviceName = "acme-sync-logging-to-rho";
      remoteUser = "acme-sync-logging";
      remoteHost = hosts.rho.wg-admin;
    }
    {
      domain = "vllm.sjanglab.org";
      serviceName = "acme-sync-vllm-to-psi";
      remoteUser = "acme-sync-vllm";
      remoteHost = hosts.psi.wg-admin;
    }
  ];

  disko.rootDisk = "/dev/vda";

  # ACME certificates for internal services
  security.acme.certs."ollama.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  security.acme.certs."vllm.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "acme";
  };

  security.acme.certs."gatus.sjanglab.org" = {
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

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
