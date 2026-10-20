{
  config,
  lib,
  ...
}:
let
  contract = (import ./contracts.nix).vaultwarden;
  resticRepository = "s3:${contract.endpoint}/${contract.bucket}/${contract.prefix}";
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;
in
{
  options.services.sbee.backups.vaultwarden.enable =
    lib.mkEnableOption "Vaultwarden file backup to the S3 backup store";

  config = lib.mkIf config.services.sbee.backups.vaultwarden.enable {
    sops.secrets.${contract.secretNames.repositoryPassword} = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/restic-restore 0755 root root - -"
    ];

    services.restic.backups.${contract.repository} = {
      repository = resticRepository;
      passwordFile = config.sops.secrets.${contract.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.eta-restic-r2-env.path;
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
