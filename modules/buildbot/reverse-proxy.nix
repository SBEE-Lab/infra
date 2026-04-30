# Buildbot reverse proxy (deployed on psi)
# No nginx auth: Buildbot uses its own Authentik OIDC integration for login
{ config, ... }:
let
  buildbotDomain = "buildbot.sjanglab.org";
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "Buildbot";
      url = "http://127.0.0.1:8010";
      group = "ci";
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

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
