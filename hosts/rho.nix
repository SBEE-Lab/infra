{ ... }:
{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/tailscale
    ../modules/postgresql
    ../modules/rustfs
    ../modules/backup/mirror.nix
    ../modules/backup/postgresql.nix
    ../modules/monitoring/vector/monitor-systems.nix
    ../modules/monitoring/systemd-status-exporter.nix
    ../modules/monitoring/reverse-proxy.nix
    ../modules/gatus/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038a";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID0 for data (4TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H96N";
        disks.hdd2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H6KD";
        mountpoint = "/srv";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  networking.hostName = "rho";

  sops.secrets = {
    rustfs-access-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
    rustfs-secret-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
  };

  services.rustfs.enable = true;
  services.sbee.backups = {
    mirror.psiProtected.enable = true;
    postgresql = {
      enable = true;
      databases = [
        "terraform"
        "nextcloud"
        "n8n"
      ];
      startAt = "*-*-* 04:30:00";
    };
    mirror.postgresql.enable = true;
  };

  services.sbee.systemdStatusExporter = {
    enable = true;
    lokiEndpoint = "http://127.0.0.1:3100";
  };

  system.stateVersion = "25.05";
}
