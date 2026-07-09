# Public Nextcloud reverse proxy for eta.
#
# Tailnet users still resolve cloud.sjanglab.org to tau through Headscale split DNS;
# this edge exists for non-tailnet users and as a fallback when client DNS caches
# the public address.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sjanglab.org";
  upstream = "https://${hosts.tau.wg-admin}";
  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Ssl on;

    proxy_request_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
  '';
in
{
  imports = [
    ../acme
    ../gatus/check.nix
  ];

  gatusCheck.pull = [
    {
      name = "Nextcloud (public edge)";
      url = "https://${domain}/status.php";
      group = "apps";
    }
  ];

  services.nginx.commonHttpConfig = ''
    limit_req_zone $binary_remote_addr zone=nextcloud_login:10m rate=10r/m;
  '';

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;

    extraConfig = ''
      access_log /var/log/nginx/access-audit/nextcloud-edge.log nginx_access_json;

      # Nextcloud handles large uploads through chunking, but direct uploads and
      # WebDAV clients still need a generous edge limit.
      client_max_body_size 10G;

      client_body_timeout 300s;
      client_header_timeout 60s;
      keepalive_timeout 75s;
    '';

    locations = {
      "/" = {
        proxyPass = upstream;
        proxyWebsockets = true;
        extraConfig = proxyHeaders;
      };

      "~ ^/(login|index\\.php/login)$" = {
        proxyPass = upstream;
        proxyWebsockets = true;
        extraConfig = proxyHeaders + ''
          limit_req zone=nextcloud_login burst=20 nodelay;
        '';
      };
    };
  };
}
