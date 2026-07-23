{ config, ... }:
let
  domain = "omnigraph.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
  port = config.services.omnigraph.port;
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-omnigraph";
    }
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      onlySSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";
      extraConfig = ''
        access_log /var/log/nginx/access-audit/omnigraph.log nginx_access_json;
        client_max_body_size 32M;

        allow 100.64.0.0/10;
        allow 10.100.0.0/24;
        deny all;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
        '';
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
