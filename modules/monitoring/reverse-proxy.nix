# Grafana reverse proxy (deployed on eta)
# Proxies requests to rho where Grafana is running on wg-admin
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  loggingDomain = "logging.sjanglab.org";
in
{
  imports = [ ../acme ];

  services.nginx.virtualHosts.${loggingDomain} = {
    forceSSL = true;
    useACMEHost = loggingDomain;

    locations = {
      "/" = {
        proxyPass = "http://${hosts.rho.wg-admin}:3000";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      # Grafana live (WebSocket)
      "/api/live/" = {
        proxyPass = "http://${hosts.rho.wg-admin}:3000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  security.acme.certs.${loggingDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    group = "nginx";
  };
}
