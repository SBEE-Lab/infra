{ config, ... }:
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.pull = [
    {
      name = "Vaultwarden";
      url = "http://127.0.0.1:8000/alive";
      group = "apps";
      conditions = [ "[STATUS] == 200" ];
    }
  ];

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

      ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_PORT = 8000;
    };
  };

  sops.secrets.vaultwarden-env = {
    sopsFile = ./secrets.yaml;
    owner = "vaultwarden";
    group = "vaultwarden";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /var/backup/vaultwarden 0700 vaultwarden vaultwarden -"
  ];

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 8000 ];
}
