# Gatus tailnet reverse proxy (deployed on rho)
{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  authentikAuth = import ../authentik/nginx-locations.nix { inherit hosts; };
  domain = "gatus.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-gatus";
    }
  ];

  services.nginx = {
    enable = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations = authentikAuth.locations // {
        "/" = {
          proxyPass = "http://${hosts.eta.wg-admin}:8081";
          proxyWebsockets = true;
          extraConfig = authentikAuth.protectLocation + ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
