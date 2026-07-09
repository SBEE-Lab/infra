# Nixbot reverse proxy/TLS endpoint on psi.
# eta provides public ingress; this vhost is the wg-admin upstream.
{ config, ... }:
let
  buildbotDomain = "buildbot.sjanglab.org";
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "Nixbot";
      group = "ci";
      systemdService = "nixbot.service";
    }
  ];

  services.nginx.enable = true;

  services.nginx.virtualHosts.${buildbotDomain} = {
    forceSSL = true;
    useACMEHost = buildbotDomain;
  };

  security.acme = {
    defaults.email = "sjang.bioe@gmail.com";
    acceptTerms = true;
    certs.${buildbotDomain} = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets.cloudflare-credentials.path;
      group = "nginx";
    };
  };

  sops.secrets.cloudflare-credentials = {
    sopsFile = ../acme/secrets.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
    80
    443
  ];
}
