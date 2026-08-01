{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.backups.stalwartR2BlobsMirror;
  bucket = "backups";
  prefix = "eta/stalwart-r2-blobs";
  backupBlobBucket = "stalwart-mail-blobs-backup";
  r2Endpoint = "https://0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
  accessKey = "eta-stalwart-r2-blobs-mirror";
  secretName = "eta-stalwart-r2-blobs-mirror-secret-key";
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;
in
{
  options.services.sbee.backups.stalwartR2BlobsMirror.enable =
    lib.mkEnableOption "delayed rho mirror for Stalwart R2 blob backup bucket";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      stalwart-r2-copy-access-key-id.sopsFile = ../stalwart/secrets.yaml;
      stalwart-r2-copy-secret-access-key.sopsFile = ../stalwart/secrets.yaml;
      ${secretName}.sopsFile = sharedBackupSecretsFile;
    };

    sops.templates.stalwart-r2-blobs-mirror-env = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        RCLONE_CONFIG=/dev/null
        RCLONE_CONFIG_STALWART_R2_BACKUP_TYPE=s3
        RCLONE_CONFIG_STALWART_R2_BACKUP_PROVIDER=Cloudflare
        RCLONE_CONFIG_STALWART_R2_BACKUP_ENDPOINT=${r2Endpoint}
        RCLONE_CONFIG_STALWART_R2_BACKUP_REGION=auto
        RCLONE_CONFIG_STALWART_R2_BACKUP_ACCESS_KEY_ID=${config.sops.placeholder.stalwart-r2-copy-access-key-id}
        RCLONE_CONFIG_STALWART_R2_BACKUP_SECRET_ACCESS_KEY=${config.sops.placeholder.stalwart-r2-copy-secret-access-key}
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_TYPE=s3
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_PROVIDER=Minio
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_ENDPOINT=http://${config.networking.sbee.currentHost.wg-admin}:9100
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_ACCESS_KEY_ID=${accessKey}
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_SECRET_ACCESS_KEY=${config.sops.placeholder.${secretName}}
        RCLONE_CONFIG_RHO_STALWART_R2_BLOBS_REGION=us-east-1
      '';
    };

    services.rustfs = {
      ensurePolicies.${accessKey}.statements = [
        {
          actions = [ "s3:ListBucket" ];
          resources = [ "arn:aws:s3:::${bucket}" ];
          condition.StringLike."s3:prefix" = [
            prefix
            "${prefix}/*"
          ];
        }
        {
          actions = [ "s3:GetBucketLocation" ];
          resources = [ "arn:aws:s3:::${bucket}" ];
        }
        {
          actions = [
            "s3:GetObject"
            "s3:PutObject"
            "s3:AbortMultipartUpload"
            "s3:ListMultipartUploadParts"
          ];
          resources = [ "arn:aws:s3:::${bucket}/${prefix}/*" ];
        }
      ];
      ensureUsers = [
        {
          name = accessKey;
          secretKeyFile = config.sops.secrets.${secretName}.path;
          policies = [ accessKey ];
        }
      ];
    };

    systemd.services.stalwart-r2-blobs-mirror = {
      description = "Delayed mirror of Stalwart R2 blob backup bucket to rho RustFS";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "rustfs-bootstrap.service"
      ];
      requires = [ "rustfs-bootstrap.service" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.stalwart-r2-blobs-mirror-env.path;
      };
      script = ''
        set -euo pipefail
        ${pkgs.rclone}/bin/rclone copy \
          stalwart_r2_backup:${backupBlobBucket}/ \
          rho_stalwart_r2_blobs:${bucket}/${prefix}/ \
          --immutable \
          --min-age 24h \
          --s3-no-check-bucket \
          --transfers 4 \
          --checkers 8 \
          --fast-list \
          --stats 30s \
          --stats-one-line
      '';
    };

    systemd.timers.stalwart-r2-blobs-mirror = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "2h";
        Unit = "stalwart-r2-blobs-mirror.service";
      };
    };

    services.sbee.systemdStatusExporter.units = [
      (mkSystemdJobSpec {
        unit = "stalwart-r2-blobs-mirror.service";
        jobClass = "backup";
        triggerKind = "timer";
        maxSuccessAgeSeconds = 36 * 3600;
      })
    ];
  };
}
