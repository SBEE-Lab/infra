{
  config,
  lib,
  pkgs,
}:
let
  mkPolicies =
    contract: lib.sbee.backup.mkResticOperationPolicies { inherit (contract) bucket prefix; };
  safeName = name: builtins.replaceStrings [ "-" ] [ "_" ] name;
  rcloneEnvPrefix = contract: lib.toUpper (safeName contract.repository);
  tauRemote = contract: "${safeName contract.repository}_tau";
  rhoRemote = contract: "${safeName contract.repository}_rho";
in
{
  mkPrimary =
    {
      contracts,
      sharedBackupSecretsFile,
      ensureBuckets ? false,
    }:
    {
      sops.secrets = lib.mergeAttrsList (
        map (contract: {
          ${contract.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
          ${contract.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
          ${contract.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
        }) contracts
      );

      services.rustfs = {
        ensureBuckets = lib.mkIf ensureBuckets (lib.unique (map (contract: contract.bucket) contracts));
        ensurePolicies = lib.mergeAttrsList (
          map (
            contract:
            let
              policies = mkPolicies contract;
            in
            {
              ${contract.accessKeys.writer} = policies.writer;
              ${contract.accessKeys.reader} = policies.reader;
              ${contract.accessKeys.pruner} = policies.pruner;
            }
          ) contracts
        );
        ensureUsers = lib.flatten (
          map (contract: [
            {
              name = contract.accessKeys.writer;
              secretKeyFile = config.sops.secrets.${contract.secretNames.writer}.path;
              policies = [ contract.accessKeys.writer ];
            }
            {
              name = contract.accessKeys.reader;
              secretKeyFile = config.sops.secrets.${contract.secretNames.reader}.path;
              policies = [ contract.accessKeys.reader ];
            }
            {
              name = contract.accessKeys.pruner;
              secretKeyFile = config.sops.secrets.${contract.secretNames.pruner}.path;
              policies = [ contract.accessKeys.pruner ];
            }
          ]) contracts
        );
      };
    };

  mkMirror =
    {
      contracts,
      sharedBackupSecretsFile,
      mirrorEnvTemplateName,
      ensureBuckets ? false,
    }:
    {
      sops.secrets = lib.mergeAttrsList (
        map (contract: {
          ${contract.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
          ${contract.secretNames.mirror} = { };
        }) contracts
      );

      sops.templates.${mirrorEnvTemplateName} = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          RCLONE_CONFIG=/dev/null
        ''
        + lib.concatMapStringsSep "\n" (contract: ''
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_TYPE=s3
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_PROVIDER=Minio
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_ENDPOINT=http://${config.networking.sbee.hosts.tau.wg-admin}:9100
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_ACCESS_KEY_ID=${contract.accessKeys.reader}
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_SECRET_ACCESS_KEY=${
            config.sops.placeholder.${contract.secretNames.reader}
          }
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_TAU_REGION=us-east-1
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_TYPE=s3
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_PROVIDER=Minio
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_ENDPOINT=http://${config.networking.sbee.currentHost.wg-admin}:9100
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_ACCESS_KEY_ID=${contract.accessKeys.mirror}
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_SECRET_ACCESS_KEY=${
            config.sops.placeholder.${contract.secretNames.mirror}
          }
          RCLONE_CONFIG_${rcloneEnvPrefix contract}_RHO_REGION=us-east-1
        '') contracts;
      };

      services.rustfs = {
        ensureBuckets = lib.mkIf ensureBuckets (lib.unique (map (contract: contract.bucket) contracts));
        ensurePolicies = lib.mergeAttrsList (
          map (
            contract:
            let
              policies = mkPolicies contract;
            in
            {
              ${contract.accessKeys.mirror} = policies.mirror;
            }
          ) contracts
        );
        ensureUsers = map (contract: {
          name = contract.accessKeys.mirror;
          secretKeyFile = config.sops.secrets.${contract.secretNames.mirror}.path;
          policies = [ contract.accessKeys.mirror ];
        }) contracts;
      };

      systemd.services = lib.mergeAttrsList (
        map (contract: {
          "backup-mirror-${contract.repository}" = {
            description = "Delayed copy-only mirror for ${contract.repository}";
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
                ${tauRemote contract}:${contract.bucket}/${contract.prefix}/ \
                ${rhoRemote contract}:${contract.bucket}/${contract.prefix}/ \
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
        }) contracts
      );

      systemd.timers = lib.mergeAttrsList (
        map (contract: {
          "backup-mirror-${contract.repository}" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "daily";
              Persistent = true;
              RandomizedDelaySec = "2h";
              Unit = "backup-mirror-${contract.repository}.service";
            };
          };
        }) contracts
      );

      services.sbee.systemdStatusExporter.units = map (
        contract: "backup-mirror-${contract.repository}.service"
      ) contracts;
    };
}
