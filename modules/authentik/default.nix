{ config, ... }:
{
  imports = [
    ../acme
    ../gatus/check.nix
  ];

  gatusCheck.pull = [
    {
      name = "Authentik";
      url = "https://auth.sjanglab.org";
      group = "auth";
    }
  ];

  services.authentik = {
    enable = true;
    environmentFile = config.sops.secrets.authentik-env.path;
    settings = {
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };

  sops.secrets.authentik-env = {
    sopsFile = ./secrets.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # ACME certificate
  security.acme.certs."auth.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts."auth.sjanglab.org" = {
    forceSSL = true;
    useACMEHost = "auth.sjanglab.org";

    locations."/" = {
      proxyPass = "http://127.0.0.1:9000";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Allow Authentik outpost access from internal hosts via WireGuard
  # Used for forward auth (nginx auth_request) on tau, psi
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 9000 ];
}
