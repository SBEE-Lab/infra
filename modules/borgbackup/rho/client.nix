# PostgreSQL backup from rho to tau via borgbackup
# Replaces pg_dump + rsync approach
{ config, ... }:
let
  pgPackage = config.services.postgresql.package;
  backupDir = "/var/backup/postgresql";
in
{
  # Ensure backup directory exists
  systemd.tmpfiles.rules = [
    "d ${backupDir} 0750 postgres postgres -"
  ];

  # Pre-backup service: dump PostgreSQL databases
  systemd.services.postgresql-dump-for-borg = {
    description = "Dump PostgreSQL for borgbackup";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
    };

    script = ''
      ${pgPackage}/bin/pg_dumpall > ${backupDir}/pg_dumpall.sql
      chmod 600 ${backupDir}/pg_dumpall.sql
    '';
  };

  # Borg job depends on the dump service
  systemd.services.borgbackup-job-rho-postgresql = {
    after = [ "postgresql-dump-for-borg.service" ];
    requires = [ "postgresql-dump-for-borg.service" ];
  };

  services.borgbackup.jobs.rho-postgresql = {
    paths = [ backupDir ];
    repo = "borg@${config.networking.sbee.hosts.tau.wg-admin}:/backup/borg/rho";
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg-passphrase-rho.path}";
    };
    environment.BORG_RSH = "ssh -i ${config.sops.secrets.borg-ssh-key-rho.path} -p 10022";
    compression = "auto,zstd,10";
    startAt = "*-*-* 04:00:00"; # 1 hour after psi backup
    persistentTimer = true;
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
    postHook = ''
      if [ "$exitStatus" != "0" ]; then
        echo "Borgbackup PostgreSQL failed on ${config.networking.hostName} with status $exitStatus" >&2
      fi
    '';
  };

  sops.secrets.borg-ssh-key-rho = {
    sopsFile = ./secrets.yaml;
    mode = "0400";
  };
  sops.secrets.borg-passphrase-rho = {
    sopsFile = ./secrets.yaml;
  };
}
