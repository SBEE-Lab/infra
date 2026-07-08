{ config, lib, ... }:
let
  cfg = config.services.sbee.backups.primary;
  resticStore = import ./restic-store.nix {
    inherit config lib;
    pkgs = null;
  };
  sharedBackupSecretsFile = ../../hosts/shared/psi-backup.yaml;
  postgresqlContracts = lib.attrValues lib.sbee.backup.contracts.postgresql;
  contracts =
    lib.optional cfg.psiProtected.enable lib.sbee.backup.contracts.psiProtected
    ++ lib.optionals cfg.postgresql.enable postgresqlContracts;
in
{
  options.services.sbee.backups.primary = {
    psiProtected.enable = lib.mkEnableOption "primary RustFS storage state for psi protected backups";
    postgresql.enable = lib.mkEnableOption "primary RustFS storage state for PostgreSQL restic backups";
  };

  config = lib.mkIf (contracts != [ ]) (
    resticStore.mkPrimary {
      inherit contracts sharedBackupSecretsFile;
      ensureBuckets = true;
    }
  );
}
