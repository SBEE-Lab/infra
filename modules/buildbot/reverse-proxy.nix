# Buildbot reverse proxy (deployed on eta)
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

    locations = {
      "/" = {
        proxyPass = "http://${hosts.psi.wg-admin}:8010";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      "/ws" = {
        proxyPass = "http://${hosts.psi.wg-admin}:8010";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 6000s;
        '';
      };
      "/sse" = {
        proxyPass = "http://${hosts.psi.wg-admin}:8010";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
          proxy_cache off;
        '';
      };
    };
  };

  security.acme.certs.${buildbotDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    group = "nginx";
  };
}
