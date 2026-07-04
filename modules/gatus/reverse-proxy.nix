{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  domain = "status.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
in
{
  imports = [
    ./check.nix
    ../acme/sync.nix
  ];

  gatusCheck.push = [
    {
      name = "Gatus";
      group = "monitoring";
      url = "https://${domain}/";
    }
  ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-status";
    }
  ];

  services.nginx = {
    enable = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations."/" = {
        proxyPass = "http://${hosts.eta.wg-admin}:8081";
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

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
