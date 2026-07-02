{
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.enable = true;

  # Avoid importing a stale root pool from another installation by default.
  boot.zfs.forceImportRoot = false;
}
