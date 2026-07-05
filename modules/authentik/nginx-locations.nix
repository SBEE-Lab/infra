# Shared Authentik forward auth nginx locations
#
# Usage:
#   let
#     authentikAuth = import ../authentik/nginx-locations.nix { inherit (config.networking.sbee) hosts; };
#   in
#   {
#     services.nginx.virtualHosts.${domain}.locations = authentikAuth.locations // {
#       "/" = {
#         proxyPass = "http://127.0.0.1:${port}";
#         extraConfig = authentikAuth.protectLocation + ''
#           client_max_body_size 100M;
#         '';
#       };
#     };
#   }
{ hosts }:
let
  authentikOutpost = "http://${hosts.eta.wg-admin}:9000";
in
{
  # Add these locations to an nginx virtualHost for Authentik forward auth
  locations = {
    # Auth endpoint (internal, for auth_request subrequest)
    "/outpost.goauthentik.io/auth/nginx" = {
      proxyPass = "${authentikOutpost}/outpost.goauthentik.io/auth/nginx";
      # extraConfig sets all headers the outpost needs; the recommended-proxy
      # include would duplicate Host/X-Forwarded-* and the embedded outpost
      # rejects requests with duplicated headers (400).
      recommendedProxySettings = false;
      extraConfig = ''
        internal;
        proxy_pass_request_body off;
        proxy_set_header Content-Length 0;
        proxy_set_header Host $host;
        proxy_set_header X-Original-URL $scheme://$host$request_uri;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;
      '';
    };

    # Start/callback (external, for browser redirects)
    "/outpost.goauthentik.io" = {
      proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
      # Same duplicated-header opt-out as the auth endpoint above.
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Original-URL $scheme://$host$request_uri;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Authorization $http_authorization;
      '';
    };

    # Signin redirect (same domain, not auth.sjanglab.org)
    "@authentik_signin" = {
      extraConfig = ''
        internal;
        return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
      '';
    };
  };

  # Add this to extraConfig of locations protected by Authentik
  protectLocation = ''
    auth_request /outpost.goauthentik.io/auth/nginx;
    auth_request_set $authentik_email $upstream_http_x_authentik_email;
    error_page 401 = @authentik_signin;
    proxy_set_header X-authentik-email $authentik_email;
  '';
}
