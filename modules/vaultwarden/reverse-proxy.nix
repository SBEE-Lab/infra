_:
let
  domain = "vault.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-vaultwarden";
    }
  ];

  services.nginx = {
    enable = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
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
