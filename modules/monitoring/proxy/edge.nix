# Public Grafana ingress; authentication remains on rho's local proxy.
{ config, pkgs, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "logging.sjanglab.org";
in
{
  imports = [ ../audit/nginx-access-logs.nix ];

  services.sbee.nginx.edgeVhosts.${domain} = { };

  services.nginx.virtualHosts.${domain} = {
    extraConfig = ''
      access_log /var/log/nginx/access-audit/grafana-edge.log nginx_access_json;
    '';

    locations = {
      "/" = {
        proxyPass = "https://${hosts.rho.wg-admin}";
        proxyWebsockets = true;
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name ${domain};
          proxy_ssl_verify on;
          # Cross-signed public certificate chains need multiple intermediates.
          proxy_ssl_verify_depth 4;
          proxy_ssl_trusted_certificate ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt;
          proxy_set_header Host ${domain};
          proxy_set_header X-Forwarded-Host ${domain};
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
          # Only rho's Authentik subrequest may supply the identity header.
          proxy_set_header X-authentik-email "";
        '';
      };

      # These share rho's private vhost but are not public Grafana routes.
      "= /prometheus".return = "404";
      "^~ /prometheus/".return = "404";
      "= /alertmanager".return = "404";
      "^~ /alertmanager/".return = "404";
    };
  };
}
