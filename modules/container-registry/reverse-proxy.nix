# TLS endpoint for zot on psi. eta provides public ingress over wg-admin; local
# clients reach it directly so pulls on psi never leave the host.
{ config, ... }:
let
  inherit (config.networking.sbee) currentHost;
  domain = "registry.sjanglab.org";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-registry";
    }
  ];

  # k3s, docker and skopeo on psi resolve the public name to this vhost.
  networking.hosts.${currentHost.wg-admin} = [ domain ];

  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
      locations."/" = {
        proxyPass = "http://127.0.0.1:5000";
        extraConfig = ''
          client_max_body_size 50g;
          client_body_timeout 300s;
          send_timeout 300s;
          proxy_send_timeout 1800s;
          proxy_read_timeout 1800s;
          proxy_request_buffering off;
          proxy_buffering off;

          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 443 ];
}
