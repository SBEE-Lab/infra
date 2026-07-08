{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.backups.psiProtected;
  psiProtected = lib.sbee.backup.contracts.psiProtected;
  protectedRepository = psiProtected.repository;
  resticRepository = "s3:http://${config.networking.sbee.hosts.tau.wg-admin}:9100/${psiProtected.bucket}/${psiProtected.prefix}";
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  resticEnvTemplateName = role: "restic-${protectedRepository}-${role}-env";
in
{
  options.services.sbee.backups.psiProtected = {
    enable = lib.mkEnableOption "protected psi restic backup to RustFS";

    blobsQuotaBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 200 * 1024 * 1024 * 1024;
      description = "Maximum allowed /blobs size before backup.";
    };

    projectBudgetBytes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10 * 1024 * 1024 * 1024;
      description = "Maximum allowed /project size before backup.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      ${psiProtected.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.repositoryPassword} = { };
    };

    sops.templates.${resticEnvTemplateName "writer"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.writer}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.writer}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };
    sops.templates.${resticEnvTemplateName "reader"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.reader}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.reader}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };
    sops.templates.${resticEnvTemplateName "pruner"} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.pruner}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.pruner}}
        AWS_DEFAULT_REGION=us-east-1
      '';
    };

    systemd.tmpfiles.rules = [
      "f /project/.rustic-backup-sentinel 0644 root root - -"
      "w /project/.rustic-backup-sentinel - - - - psi protected backup sentinel"
      "d /var/lib/restic-restore 0755 root root - -"
    ];

    services.restic.backups = {
      ${protectedRepository} = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
        environmentFile = config.sops.templates.${resticEnvTemplateName "writer"}.path;
        paths = [
          "/project"
          "/blobs"
        ];
        initialize = true;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };

      "${protectedRepository}-check" = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
        environmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
        timerConfig = {
          OnCalendar = "monthly";
          Persistent = true;
        };
        runCheck = true;
        checkOpts = [ "--no-lock" ];
        createWrapper = false;
      };

      "${protectedRepository}-prune" = {
        repository = resticRepository;
        passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
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

    systemd.services."backup-guard-${protectedRepository}" = {
      description = "Guard restic backup source size: ${protectedRepository}";
      after = [ "xfs-project-quota-root.service" ];
      requires = [ "xfs-project-quota-root.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -euo pipefail
        blobs_bytes=$(${pkgs.coreutils}/bin/du -sb /blobs | ${pkgs.coreutils}/bin/cut -f1)
        if [ "$blobs_bytes" -gt ${toString cfg.blobsQuotaBytes} ]; then
          echo "/blobs exceeds protected backup budget: $blobs_bytes > ${toString cfg.blobsQuotaBytes}" >&2
          exit 1
        fi

        project_bytes=$(${pkgs.coreutils}/bin/du -sb /project | ${pkgs.coreutils}/bin/cut -f1)
        if [ "$project_bytes" -gt ${toString cfg.projectBudgetBytes} ]; then
          echo "/project exceeds protected backup budget: $project_bytes > ${toString cfg.projectBudgetBytes}" >&2
          exit 1
        fi
      '';
    };

    systemd.services."restic-backups-${protectedRepository}" = {
      after = [ "backup-guard-${protectedRepository}.service" ];
      requires = [ "backup-guard-${protectedRepository}.service" ];
    };

    systemd.services."restic-restore-drill-${protectedRepository}" = {
      description = "Restore drill for restic repository: ${protectedRepository}";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment = {
        RESTIC_REPOSITORY = resticRepository;
        RESTIC_PASSWORD_FILE = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
        RESTIC_CACHE_DIR = "/var/cache/restic-restore-drill-${protectedRepository}";
      };
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
        CacheDirectory = "restic-restore-drill-${protectedRepository}";
        CacheDirectoryMode = "0700";
      };
      script = ''
        set -euo pipefail
        target=/var/lib/restic-restore/${protectedRepository}
        ${pkgs.coreutils}/bin/rm -rf "$target"
        ${pkgs.coreutils}/bin/mkdir -p "$target"
        ${pkgs.restic}/bin/restic --no-lock restore latest --target "$target" --include /project/.rustic-backup-sentinel
        ${pkgs.diffutils}/bin/cmp /project/.rustic-backup-sentinel "$target/project/.rustic-backup-sentinel"
        ${pkgs.coreutils}/bin/rm -rf "$target"
      '';
    };

    systemd.timers."restic-restore-drill-${protectedRepository}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        Unit = "restic-restore-drill-${protectedRepository}.service";
      };
    };

    services.prometheus.exporters.restic = {
      enable = true;
      listenAddress = config.networking.sbee.currentHost.wg-admin;
      port = 9753;
      repository = resticRepository;
      passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
      refreshInterval = 3600;
    };

    # The monthly restic check job remains the source of truth for repository
    # integrity. The exporter still reports snapshot freshness without running a
    # check every scrape cycle.
    systemd.services.prometheus-restic-exporter.environment.NO_CHECK = "1";

    networking.firewall.interfaces."wg-admin".allowedTCPPorts = [
      9753 # restic exporter
    ];

    services.sbee.systemdStatusExporter.units = [
      "backup-guard-${protectedRepository}.service"
      "restic-backups-${protectedRepository}.service"
      "restic-backups-${protectedRepository}-check.service"
      "restic-backups-${protectedRepository}-prune.service"
      "restic-restore-drill-${protectedRepository}.service"
    ];
  };
}
