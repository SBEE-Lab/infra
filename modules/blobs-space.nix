{
  # Create blobs space for storing licensed or large file that requires for nix packages. (backed up)
  # /blobs is stored on the local rootfs (4TB SSD).
  systemd.tmpfiles.rules = [
    "d /blobs 0755 root root -"
  ];
}
