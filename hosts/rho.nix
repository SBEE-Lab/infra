{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/postgresql
    ../modules/buildbot/database.nix
    ../modules/buildbot/terraform-worker.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038a";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID0 for data (4TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H96N";
        disks.hdd2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H6KD";
        mountpoint = "/backup";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  networking.hostName = "rho";

  system.stateVersion = "25.05";
}
