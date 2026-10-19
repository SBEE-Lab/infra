{ config, lib, ... }:
let
  hostName = config.networking.hostName;
  mountpoint = config.disko.xfsMdadm.arrays.data.mountpoint;
  postgresEnabled = config.services.postgresql.enable;
in
{
  sops.secrets.borg-passphrase = { };

  services.borgbackup.jobs.local = {
    repo = "${mountpoint}/borg/${hostName}";
    paths = [
      "/"
      "/boot"
    ];
    exclude = [
      "pp:${mountpoint}"
      "pp:/dev"
      "pp:/home"
      "pp:/proc"
      "pp:/run"
      "pp:/sys"
    ]
    ++ lib.optional (
      config.disko.xfsMdadm.arrays ? workspace
    ) "pp:${config.disko.xfsMdadm.arrays.workspace.mountpoint}"
    ++ lib.optional postgresEnabled "pp:${config.services.postgresql.dataDir}";

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg-passphrase.path}";
    };
    compression = "auto,zstd";
    # Keep warning results distinct from clean, complete backups.
    failOnWarnings = true;
    # Schedule only after the initial backup and restore have been verified.
    startAt = [ ];
    extraCreateArgs = [
      "--one-file-system"
      "--stats"
    ];
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };

  systemd.services.borgbackup-job-local = {
    requires = lib.optional postgresEnabled "postgresqlBackup.service";
    after = lib.optional postgresEnabled "postgresqlBackup.service";
    unitConfig.RequiresMountsFor = [ "/boot" ];
  };

  # Raw PGDATA is not a consistent live backup; dump all local databases and roles.
  services.postgresqlBackup = lib.mkIf postgresEnabled {
    enable = true;
    backupAll = true;
    compression = "none";
    startAt = [ ];
  };
  systemd.services.postgresqlBackup = lib.mkIf postgresEnabled {
    after = [ "postgresql.service" ];
  };
}
