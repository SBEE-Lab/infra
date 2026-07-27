# Public Documenso reverse proxy for eta.
#
# Documenso signing links need to be reachable by external recipients; tailnet
# users still resolve the service to tau through Headscale split DNS.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "documenso.sjanglab.org";
  upstream = "https://${hosts.tau.wg-admin}";
in
{
  imports = [
    ../acme
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.pull = [
    {
      name = "Documenso (public edge)";
      url = "https://${domain}";
      group = "apps";
    }
  ];

  acmeSyncer.mkSender = [
    {
      inherit domain;
      serviceName = "acme-sync-documenso-to-tau";
      remoteUser = "acme-sync-documenso";
      remoteHost = hosts.tau.wg-admin;
    }
  ];

  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;

    extraConfig = ''
      access_log /var/log/nginx/access-audit/documenso-edge.log nginx_access_json;
      client_max_body_size 64M;
    '';

    locations."/" = {
      proxyPass = upstream;
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
      '';
    };
  };
}
