# Public Nextcloud reverse proxy for eta.
#
# Tailnet users still resolve cloud.sjanglab.org to tau through Headscale split DNS;
# this edge exists for non-tailnet users and as a fallback when client DNS caches
# the public address.
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sjanglab.org";
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

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;

    extraConfig = ''
      access_log /var/log/nginx/access-audit/nextcloud-edge.log nginx_access_json;

      # Nextcloud handles large uploads through chunking, but direct uploads and
      # WebDAV clients still need a generous edge limit.
      client_max_body_size 10G;
    '';

    locations."/" = {
      proxyPass = "https://${hosts.tau.wg-admin}";
      proxyWebsockets = true;
      extraConfig = ''
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
    };
  };
}
