{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/nvidia.nix
    ../modules/tailscale
    ../modules/buildbot/master.nix
    ../modules/buildbot/worker.nix
    ../modules/borgbackup/psi/client.nix
    ../modules/monitoring/vector
    ../modules/harmonia
    ../modules/icebox/databases.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y404280K";

  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # SSD RAID0 for workspace (16TB total)
      workspace = {
        disks.ssd1 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA05025J";
        disks.ssd2 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA02750H";
        mountpoint = "/workspace";
        extraXfsOptions = [
          "allocsize=16m"
        ];
      };
      # HDD RAID0 for data (60TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0HG8X";
        disks.hdd2 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0H1A7";
        mountpoint = "/data";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  # Enable periodic TRIM for SSD health
  services.fstrim.enable = true;

  # Use localhost for harmonia cache instead of wireguard IP
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "http://127.0.0.1:5000"
  ];

  networking.hostName = "psi";

  # Database management with icebox
  services.icebox = {
    enable = true;
    root = "/workspace/shared/databases";

    # Enable databases needed for research
    databases = {
      blast-nr.enable = true;
      blast-nt.enable = true;
      blast-swissprot.enable = true;
      uniref90.enable = true;
      uniref100.enable = true;
      pdb.enable = true;
      pdb-mmcif.enable = true;
      rnacentral.enable = true;
      pfam.enable = true;
      rfam.enable = true;
      # alphafold.enable = true;  # Very large, enable when needed
    };
  };

  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  system.stateVersion = "25.05";
}
