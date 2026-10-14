# Nixbot reverse proxy/TLS endpoint on psi.
# eta provides public ingress; this vhost is the wg-admin upstream.
_:
let
  nixbotDomain = "nixbot.sjanglab.org";
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Nixbot";
      group = "ci";
      systemdService = "nixbot.service";
    }
  ];

  services.nginx.enable = true;

  services.nginx.virtualHosts.${nixbotDomain} = {
    forceSSL = true;
    sslCertificate = "/var/lib/acme/${nixbotDomain}/fullchain.pem";
    sslCertificateKey = "/var/lib/acme/${nixbotDomain}/key.pem";
  };

  acmeSyncer.mkReceiver = [
    {
      domain = nixbotDomain;
      user = "acme-sync-nixbot";
    }
  ];

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
    80
    443
  ];
}
