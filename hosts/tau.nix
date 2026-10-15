{ ... }:
{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/tailscale
    ../modules/postgresql/replica.nix
    ../modules/rustfs
    ../modules/backup/primary.nix
    ../modules/monitoring/vector/monitor-services.nix
    ../modules/nextcloud
    ../modules/n8n
    ../modules/vaultwarden/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038f";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID1 for data (2TB usable)
      data = {
        level = 1;
        disks.hdd1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153HDND";
        disks.hdd2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WX62AC455S8R";
        mountpoint = "/srv";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  # These hosts use a local display and keyboard, not a serial console.
  srvos.boot.consoles = [ "tty0" ];
  systemd.services."serial-getty@ttyS0".enable = false;

  networking.hostName = "tau";

  services.sbee.backups = {
    primary = {
      psiProtected.enable = true;
      vaultwarden.enable = true;
      postgresql.enable = true;
    };
  };

  system.stateVersion = "25.05";
}
