{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.backups.psiProtectedMirror;
  psiProtected = lib.sbee.backup.contracts.psiProtected;
  psiProtectedPolicies = lib.sbee.backup.mkResticOperationPolicies {
    inherit (psiProtected) bucket prefix;
  };
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  mirrorEnvTemplateName = "rclone-${psiProtected.repository}-mirror-env";
in
{
  options.services.sbee.backups.psiProtectedMirror.enable =
    lib.mkEnableOption "delayed rho mirror for psi protected backups";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      ${psiProtected.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.mirror} = { };
    };

    sops.templates.${mirrorEnvTemplateName} = {
      owner = "root";
      group = "root";
      mode = "0400";
      content = ''
        RCLONE_CONFIG=/dev/null
        RCLONE_CONFIG_TAU_TYPE=s3
        RCLONE_CONFIG_TAU_PROVIDER=Minio
        RCLONE_CONFIG_TAU_ENDPOINT=http://${config.networking.sbee.hosts.tau.wg-admin}:9100
        RCLONE_CONFIG_TAU_ACCESS_KEY_ID=${psiProtected.accessKeys.reader}
        RCLONE_CONFIG_TAU_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.reader}}
        RCLONE_CONFIG_TAU_REGION=us-east-1
        RCLONE_CONFIG_RHO_TYPE=s3
        RCLONE_CONFIG_RHO_PROVIDER=Minio
        RCLONE_CONFIG_RHO_ENDPOINT=http://${config.networking.sbee.currentHost.wg-admin}:9100
        RCLONE_CONFIG_RHO_ACCESS_KEY_ID=${psiProtected.accessKeys.mirror}
        RCLONE_CONFIG_RHO_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.mirror}}
        RCLONE_CONFIG_RHO_REGION=us-east-1
      '';
    };

    services.rustfs = {
      ensureBuckets = [ psiProtected.bucket ];
      ensurePolicies.${psiProtected.accessKeys.mirror} = psiProtectedPolicies.mirror;
      ensureUsers = [
        {
          name = psiProtected.accessKeys.mirror;
          secretKeyFile = config.sops.secrets.${psiProtected.secretNames.mirror}.path;
          policies = [ psiProtected.accessKeys.mirror ];
        }
      ];
    };

    systemd.services."backup-mirror-${psiProtected.repository}" = {
      description = "Delayed copy-only mirror for ${psiProtected.repository}";
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "rustfs-bootstrap.service"
      ];
      requires = [ "rustfs-bootstrap.service" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.templates.${mirrorEnvTemplateName}.path;
      };
      script = ''
        set -euo pipefail
        ${pkgs.rclone}/bin/rclone copy \
          tau:${psiProtected.bucket}/${psiProtected.prefix}/ \
          rho:${psiProtected.bucket}/${psiProtected.prefix}/ \
          --immutable \
          --min-age 24h \
          --exclude 'locks/**' \
          --s3-no-check-bucket \
          --transfers 4 \
          --checkers 8 \
          --fast-list \
          --stats 30s \
          --stats-one-line
      '';
    };

    systemd.timers."backup-mirror-${psiProtected.repository}" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "2h";
        Unit = "backup-mirror-${psiProtected.repository}.service";
      };
    };
  };
}
