{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sbee.backups.psiProtectedPrimary;
  psiProtected = lib.sbee.backup.contracts.psiProtected;
  psiProtectedPolicies = lib.sbee.backup.mkResticOperationPolicies {
    inherit (psiProtected) bucket prefix;
  };
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
in
{
  options.services.sbee.backups.psiProtectedPrimary.enable =
    lib.mkEnableOption "primary RustFS storage state for psi protected backups";

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      ${psiProtected.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
      ${psiProtected.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
    };

    services.rustfs = {
      ensureBuckets = [ psiProtected.bucket ];
      ensurePolicies = {
        ${psiProtected.accessKeys.writer} = psiProtectedPolicies.writer;
        ${psiProtected.accessKeys.reader} = psiProtectedPolicies.reader;
        ${psiProtected.accessKeys.pruner} = psiProtectedPolicies.pruner;
      };
      ensureUsers = [
        {
          name = psiProtected.accessKeys.writer;
          secretKeyFile = config.sops.secrets.${psiProtected.secretNames.writer}.path;
          policies = [ psiProtected.accessKeys.writer ];
        }
        {
          name = psiProtected.accessKeys.reader;
          secretKeyFile = config.sops.secrets.${psiProtected.secretNames.reader}.path;
          policies = [ psiProtected.accessKeys.reader ];
        }
        {
          name = psiProtected.accessKeys.pruner;
          secretKeyFile = config.sops.secrets.${psiProtected.secretNames.pruner}.path;
          policies = [ psiProtected.accessKeys.pruner ];
        }
      ];
    };
  };
}
