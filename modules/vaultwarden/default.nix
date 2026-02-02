{ config, ... }:
{
  imports = [ ../acme ];

  services.vaultwarden = {
    enable = true;
    environmentFile = config.sops.secrets.vaultwarden-env.path;
    backupDir = "/var/backup/vaultwarden";

    config = {
      DOMAIN = "https://vault.sjanglab.org";
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;

      # SSO/OIDC
      SSO_ENABLED = true;
      SSO_AUTHORITY = "https://auth.sjanglab.org/application/o/vaultwarden/";
      SSO_CLIENT_ID = "OfBSHOHF0txEZzpJgZAIahUAjfHSQQ18xNWGwyNV";
      SSO_SCOPES = "email profile openid offline_access";
      SSO_PKCE = true;
      SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION = true;

      # Organization
      ORG_CREATION_USERS = "sjang.bioe@gmail.com,admin@sjanglab.org";

      ROCKET_PORT = 8000;
    };
  };

  sops.secrets.vaultwarden-env = {
    sopsFile = ./secrets.yaml;
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "0400";
  };

  # ACME certificate (DNS challenge)
  security.acme.certs."vault.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
  };

  # Nginx reverse proxy
  services.nginx.virtualHosts."vault.sjanglab.org" = {
    forceSSL = true;
    enableACME = true;

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

  systemd.tmpfiles.rules = [
    "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
