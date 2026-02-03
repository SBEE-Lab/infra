{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "docling.sjanglab.org";
  doclingPort = 5001;
  certDir = "/var/lib/acme/${domain}";
  authentikOutpost = "http://${hosts.eta.wg-admin}:9000";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    { inherit domain; }
  ];

  # Docker container with GPU
  virtualisation.oci-containers = {
    backend = "docker";
    containers.docling = {
      image = "ghcr.io/docling-project/docling-serve-cu128:latest";
      ports = [ "127.0.0.1:${toString doclingPort}:5001" ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };
  };

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      # Authentik outpost - auth endpoint (internal, for auth_request)
      locations."/outpost.goauthentik.io/auth/nginx" = {
        proxyPass = "${authentikOutpost}/outpost.goauthentik.io/auth/nginx";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header Authorization $http_authorization;
        '';
      };

      # Authentik outpost - start/callback (external, for redirects)
      locations."/outpost.goauthentik.io" = {
        proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
        extraConfig = ''
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header Authorization $http_authorization;
        '';
      };

      # Signin redirect - same domain, not auth.sjanglab.org
      locations."@authentik_signin" = {
        extraConfig = ''
          internal;
          return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
        '';
      };

      # Main location - protected by Authentik forward auth
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString doclingPort}";
        extraConfig = ''
          # Authentik forward auth
          auth_request /outpost.goauthentik.io/auth/nginx;
          auth_request_set $authentik_email $upstream_http_x_authentik_email;
          error_page 401 = @authentik_signin;
          proxy_set_header X-authentik-email $authentik_email;

          client_max_body_size 100M;
          proxy_read_timeout 300s;
        '';
      };
    };
  };

  # Firewall: tailscale0 only (80/443 already allowed in tailscale module)
}
