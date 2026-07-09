{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.backups.postgresql;
  hostName = config.networking.hostName;
  contracts = lib.sbee.backup.contracts.postgresql;
  contract = contracts.${hostName} or null;
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  resticEnvTemplateName = role: "restic-${contract.repository}-${role}-env";
  resticRepository = "s3:http://${config.networking.sbee.hosts.tau.wg-admin}:9100/${contract.bucket}/${contract.prefix}";
  dumpService = "postgresql-dump-${contract.repository}.service";
  restoreIncludes = [
    "${cfg.location}/globals.sql"
  ]
  ++ map (db: "${cfg.location}/${db}.dump") cfg.databases;
  restoreIncludeArgs = lib.concatMapStringsSep " " (
    path: "--include ${lib.escapeShellArg path}"
  ) restoreIncludes;
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;
in
{
  options.services.sbee.backups.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL logical dumps to the S3 backup store";

    databases = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "PostgreSQL databases to dump with pg_dump.";
    };

    location = lib.mkOption {
      type = lib.types.path;
      default = "/var/backup/postgresql";
      description = "Directory where logical PostgreSQL dumps are staged before restic backup.";
    };

    startAt = lib.mkOption {
      type = with lib.types; either (listOf str) str;
      default = "daily";
      description = "Systemd calendar for the PostgreSQL restic backup.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = contract != null;
        message = "services.sbee.backups.postgresql has no backup contract for host ${hostName}";
      }
      {
        assertion = cfg.databases != [ ];
        message = "services.sbee.backups.postgresql.databases must list at least one database";
      }
    ];

    sops.secrets = {
      ${contract.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
      ${contract.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
      ${contract.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
      ${contract.secretNames.repositoryPassword} = { };
    };

    sops.templates.${resticEnvTemplateName "writer"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${contract.accessKeys.writer}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${contract.secretNames.writer}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };
    sops.templates.${resticEnvTemplateName "reader"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${contract.accessKeys.reader}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${contract.secretNames.reader}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };
    sops.templates.${resticEnvTemplateName "pruner"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${contract.accessKeys.pruner}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${contract.secretNames.pruner}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.location} 0750 postgres postgres -"
      "d /var/lib/restic-restore 0755 root root - -"
    ];

    systemd.services."postgresql-dump-${contract.repository}" = {
      description = "Dump PostgreSQL databases for restic backup: ${contract.repository}";
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      path = [
        config.services.postgresql.package
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
      };
      script = ''
        set -euo pipefail
        umask 0077

        cd ${lib.escapeShellArg cfg.location}

        rotate_dump() {
          target=$1
          if [ -e "$target" ]; then
            mv -f "$target" "$target.prev"
          fi
          mv "$target.in-progress" "$target"
        }

        pg_dumpall --globals-only > globals.sql.in-progress
        rotate_dump globals.sql

        for db in ${lib.escapeShellArgs cfg.databases}; do
          pg_dump --format=custom --create --clean --if-exists --file="$db.dump.in-progress" "$db"
          rotate_dump "$db.dump"
        done
      '';
    };

    services.restic.backups = {
      ${contract.repository} = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
        environmentFile = config.sops.templates.${resticEnvTemplateName "writer"}.path;
        paths = [ cfg.location ];
        initialize = true;
        timerConfig = {
          OnCalendar = cfg.startAt;
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };

      "${contract.repository}-check" = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
        environmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
        timerConfig = {
          OnCalendar = "monthly";
          Persistent = true;
        };
        runCheck = true;
        checkOpts = [ "--no-lock" ];
        createWrapper = false;
      };

      "${contract.repository}-prune" = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
        environmentFile = config.sops.templates.${resticEnvTemplateName "pruner"}.path;
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        createWrapper = false;
      };
    };

    systemd.services."restic-backups-${contract.repository}" = {
      after = [ dumpService ];
      requires = [ dumpService ];
    };

    systemd.services."restic-restore-drill-${contract.repository}" = {
      description = "Restore drill for PostgreSQL restic repository: ${contract.repository}";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        RESTIC_REPOSITORY = resticRepository;
        RESTIC_PASSWORD_FILE = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
        RESTIC_CACHE_DIR = "/var/cache/restic-restore-drill-${contract.repository}";
      };
      path = [ config.services.postgresql.package ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
        CacheDirectory = "restic-restore-drill-${contract.repository}";
        CacheDirectoryMode = "0700";
      };
      script = ''
        set -euo pipefail
        target=/var/lib/restic-restore/${contract.repository}
        restore_dir="$target${cfg.location}"

        ${pkgs.coreutils}/bin/rm -rf "$target"
        ${pkgs.coreutils}/bin/mkdir -p "$target"
        ${pkgs.restic}/bin/restic --no-lock restore latest --target "$target" ${restoreIncludeArgs}

        test -s "$restore_dir/globals.sql"
        for db in ${lib.escapeShellArgs cfg.databases}; do
          test -s "$restore_dir/$db.dump"
          pg_restore --list "$restore_dir/$db.dump" >/dev/null
        done

        ${pkgs.coreutils}/bin/rm -rf "$target"
      '';
    };

    systemd.timers."restic-restore-drill-${contract.repository}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "restic-restore-drill-${contract.repository}.service";
      };
    };

    services.sbee.systemdStatusExporter.units = [
      (mkSystemdJobSpec {
        unit = dumpService;
        jobClass = "backup";
        triggerKind = "dependency";
        maxSuccessAgeSeconds = 36 * 3600;
      })
      (mkSystemdJobSpec {
        unit = "restic-backups-${contract.repository}.service";
        jobClass = "backup";
        triggerKind = "timer";
        maxSuccessAgeSeconds = 36 * 3600;
      })
      (mkSystemdJobSpec {
        unit = "restic-backups-${contract.repository}-check.service";
        jobClass = "backup";
        triggerKind = "timer";
        maxSuccessAgeSeconds = 45 * 24 * 3600;
      })
      (mkSystemdJobSpec {
        unit = "restic-backups-${contract.repository}-prune.service";
        jobClass = "backup";
        triggerKind = "timer";
        maxSuccessAgeSeconds = 9 * 24 * 3600;
      })
      (mkSystemdJobSpec {
        unit = "restic-restore-drill-${contract.repository}.service";
        jobClass = "backup";
        triggerKind = "timer";
        maxSuccessAgeSeconds = 9 * 24 * 3600;
      })
    ];
  };
}
