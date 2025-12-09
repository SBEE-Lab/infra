{
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 40;
    "vm.dirty_background_ratio" = 10;
    "vm.vfs_cache_pressure" = 50;
  };
}
