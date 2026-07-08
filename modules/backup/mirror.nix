{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.backups.mirror;
  resticStore = import ./restic-store.nix { inherit config lib pkgs; };
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  postgresqlContracts = lib.attrValues lib.sbee.backup.contracts.postgresql;
  contracts =
    lib.optional cfg.psiProtected.enable lib.sbee.backup.contracts.psiProtected
    ++ lib.optionals cfg.postgresql.enable postgresqlContracts;
in
{
  options.services.sbee.backups.mirror = {
    psiProtected.enable = lib.mkEnableOption "delayed rho mirror for psi protected backups";
    postgresql.enable = lib.mkEnableOption "delayed rho mirror for PostgreSQL restic backups";
  };

  config = lib.mkIf (contracts != [ ]) (
    resticStore.mkMirror {
      inherit contracts sharedBackupSecretsFile;
      mirrorEnvTemplateName = "rclone-backup-mirror-env";
      ensureBuckets = true;
    }
  );
}
