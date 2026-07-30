{
  config,
  lib,
  pkgs,
  ...
}:
let
  r2Endpoint = "https://0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
  primaryBlobBucket = "stalwart-mail-blobs";
  backupBlobBucket = "stalwart-mail-blobs-backup";
  inherit (lib.sbee.monitoring) mkSystemdJobSpec;
in
{
  sops.secrets = {
    stalwart-r2-copy-access-key-id.sopsFile = ./secrets.yaml;
    stalwart-r2-copy-secret-access-key.sopsFile = ./secrets.yaml;
  };

  sops.templates.stalwart-r2-copy-env = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      RCLONE_CONFIG=/dev/null
      RCLONE_CONFIG_STALWART_BLOBS_TYPE=s3
      RCLONE_CONFIG_STALWART_BLOBS_PROVIDER=Cloudflare
      RCLONE_CONFIG_STALWART_BLOBS_ENDPOINT=${r2Endpoint}
      RCLONE_CONFIG_STALWART_BLOBS_REGION=auto
      RCLONE_CONFIG_STALWART_BLOBS_ACCESS_KEY_ID=${config.sops.placeholder.stalwart-r2-copy-access-key-id}
      RCLONE_CONFIG_STALWART_BLOBS_SECRET_ACCESS_KEY=${config.sops.placeholder.stalwart-r2-copy-secret-access-key}
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_TYPE=s3
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_PROVIDER=Cloudflare
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_ENDPOINT=${r2Endpoint}
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_REGION=auto
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_ACCESS_KEY_ID=${config.sops.placeholder.stalwart-r2-copy-access-key-id}
      RCLONE_CONFIG_STALWART_BLOBS_BACKUP_SECRET_ACCESS_KEY=${config.sops.placeholder.stalwart-r2-copy-secret-access-key}
    '';
  };

  systemd.services = {
    stalwart-r2-blob-backup = {
      description = "Append-only copy of Stalwart R2 blobs to backup bucket";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.stalwart-r2-copy-env.path;
      };
      script = ''
        set -euo pipefail
        ${pkgs.rclone}/bin/rclone copy \
          stalwart_blobs:${primaryBlobBucket}/ \
          stalwart_blobs_backup:${backupBlobBucket}/ \
          --ignore-existing \
          --s3-no-check-bucket \
          --transfers 4 \
          --checkers 8 \
          --fast-list \
          --stats 30s \
          --stats-one-line
      '';
    };

    stalwart-r2-blob-restore-drill = {
      description = "Verify a Stalwart R2 blob can be read from the backup bucket";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.stalwart-r2-copy-env.path;
      };
      path = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.jq
      ];
      script = ''
        set -euo pipefail

        object="$(${pkgs.rclone}/bin/rclone lsf stalwart_blobs_backup:${backupBlobBucket}/ --files-only --recursive --s3-no-check-bucket | head -n 1)"
        if [ -z "$object" ]; then
          echo "backup bucket has no blobs yet; skipping sample check"
          exit 0
        fi

        primary_size="$(${pkgs.rclone}/bin/rclone lsjson --stat "stalwart_blobs:${primaryBlobBucket}/$object" --s3-no-check-bucket | jq -r .Size)"
        backup_size="$(${pkgs.rclone}/bin/rclone lsjson --stat "stalwart_blobs_backup:${backupBlobBucket}/$object" --s3-no-check-bucket | jq -r .Size)"

        if [ "$primary_size" != "$backup_size" ]; then
          echo "blob size mismatch for $object: primary=$primary_size backup=$backup_size" >&2
          exit 1
        fi

        ${pkgs.rclone}/bin/rclone cat "stalwart_blobs_backup:${backupBlobBucket}/$object" --s3-no-check-bucket | head -c 1 >/dev/null || true
        echo "verified backup blob sample $object ($backup_size bytes)"
      '';
    };
  };

  systemd.timers = {
    stalwart-r2-blob-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 04:10:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
        Unit = "stalwart-r2-blob-backup.service";
      };
    };

    stalwart-r2-blob-restore-drill = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-01 05:10:00";
        Persistent = true;
        RandomizedDelaySec = "30m";
        Unit = "stalwart-r2-blob-restore-drill.service";
      };
    };
  };

  services.sbee.systemdStatusExporter.units = [
    (mkSystemdJobSpec {
      unit = "stalwart-r2-blob-backup.service";
      jobClass = "backup";
      triggerKind = "timer";
      maxSuccessAgeSeconds = 36 * 3600;
    })
    (mkSystemdJobSpec {
      unit = "stalwart-r2-blob-restore-drill.service";
      jobClass = "backup";
      triggerKind = "timer";
      maxSuccessAgeSeconds = 45 * 24 * 3600;
    })
  ];
}
