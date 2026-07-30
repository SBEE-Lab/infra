# Public write endpoint for niks3 on psi.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "niks3.sjanglab.org";
in
{
  imports = [ ../acme ];

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;

    locations."/" = {
      proxyPass = "http://${hosts.psi.wg-admin}:5751";
      extraConfig = ''
        client_max_body_size 16m;
        proxy_connect_timeout 120s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        proxy_request_buffering off;
        proxy_buffering off;
      '';
    };
  };

  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };
}
