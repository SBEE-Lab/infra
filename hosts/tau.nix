{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/tailscale
    ../modules/postgresql/replica.nix
    ../modules/borgbackup/psi/server.nix
    ../modules/borgbackup/rho/server.nix
    ../modules/monitoring/vector/monitor-services.nix
    ../modules/nextcloud
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038f";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID0 for data (4TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153HDND";
        disks.hdd2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WX62AC455S8R";
        mountpoint = "/backup";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  networking.hostName = "tau";

  system.stateVersion = "25.05";
}
