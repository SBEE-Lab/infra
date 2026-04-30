# Buildbot public edge proxy (deployed on eta)
# The Buildbot stack stays on psi; eta provides public ingress because psi's
# datacenter network does not accept inbound Internet traffic.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  buildbotDomain = "buildbot.sjanglab.org";
in
{
  imports = [ ../acme ];

  services.nginx.virtualHosts.${buildbotDomain} = {
    forceSSL = true;
    useACMEHost = buildbotDomain;

    locations."/" = {
      proxyPass = "https://${hosts.psi.wg-admin}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name ${buildbotDomain};
      '';
    };
  };

  security.acme.certs.${buildbotDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };
}
