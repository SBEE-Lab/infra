{
  config,
  lib,
  ...
}:
let
  contract = lib.sbee.backup.contracts.vaultwarden;
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  resticEnvTemplateName = role: "restic-${contract.repository}-${role}-env";
  resticRepository = "s3:http://${config.networking.sbee.hosts.tau.wg-admin}:9100/${contract.bucket}/${contract.prefix}";
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;
in
{
  options.services.sbee.backups.vaultwarden.enable =
    lib.mkEnableOption "Vaultwarden file backup to the S3 backup store";

  config = lib.mkIf config.services.sbee.backups.vaultwarden.enable {
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
      "d /var/lib/restic-restore 0755 root root - -"
    ];

    services.restic.backups.${contract.repository} = {
      repository = resticRepository;
      passwordFile = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.${resticEnvTemplateName "writer"}.path;
      initialize = true;
      paths = [
        "/var/lib/vaultwarden"
        "/var/backup/vaultwarden"
      ];
      timerConfig = {
        OnCalendar = "*-*-* 02:45:00";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      checkOpts = [ "--read-data-subset=10%" ];
    };

    systemd.services."restic-backups-${contract.repository}".after = [ "vaultwarden.service" ];

    services.sbee.systemdStatusExporter.units = [
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
        maxSuccessAgeSeconds = 8 * 24 * 3600;
      })
    ];
  };
}
