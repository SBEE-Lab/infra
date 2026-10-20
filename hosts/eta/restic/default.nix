{ config, ... }:
{
  imports = [
    ./postgresql.nix
    ./vaultwarden.nix
  ];

  assertions = [
    {
      assertion = config.networking.hostName == "eta";
      message = "The legacy Restic backup module belongs to eta.";
    }
  ];

  sops.secrets = {
    restic-r2-access-key-id = { };
    restic-r2-secret-access-key = { };
  };

  sops.templates.eta-restic-r2-env = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.restic-r2-access-key-id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.restic-r2-secret-access-key}
      AWS_DEFAULT_REGION=auto
    '';
  };

  services.sbee.backups = {
    postgresql = {
      enable = true;
      databases = [
        "authentik"
        "gitea-mq"
        "stalwart-mail"
      ];
      startAt = "*-*-* 03:30:00";
    };
    vaultwarden.enable = true;
  };
}
