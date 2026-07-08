{
  config,
  lib,
  ...
}:
let
  psiProtected = lib.sbee.backup.contracts.psiProtected;
  psiProtectedPolicies = lib.sbee.backup.mkResticOperationPolicies {
    inherit (psiProtected) bucket prefix;
  };
  sharedBackupSecretsFile = ../hosts/shared/psi-backup.yaml;
in
{
  imports = [
    ../modules/hardware/asrock-deskmini-x600.nix
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/wake-on-lan.nix
    ../modules/tailscale
    ../modules/postgresql/replica.nix
    ../modules/rustfs
    ../modules/monitoring/vector/monitor-services.nix
    ../modules/nextcloud
    ../modules/n8n
    ../modules/vaultwarden/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038f";
  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # HDD RAID0 for data (4TB total)
      data = {
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

  networking.hostName = "tau";

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
    ${psiProtected.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
    ${psiProtected.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
    ${psiProtected.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
  };

  services.rustfs = {
    enable = true;
    ensureBuckets = [ psiProtected.bucket ];
    ensurePolicies = {
      ${psiProtected.accessKeys.writer} = psiProtectedPolicies.writer;
      ${psiProtected.accessKeys.reader} = psiProtectedPolicies.reader;
      ${psiProtected.accessKeys.pruner} = psiProtectedPolicies.pruner;
    };
    ensureUsers = [
      {
        name = psiProtected.accessKeys.writer;
        secretKeyFile = config.sops.secrets.${psiProtected.secretNames.writer}.path;
        policies = [ psiProtected.accessKeys.writer ];
      }
      {
        name = psiProtected.accessKeys.reader;
        secretKeyFile = config.sops.secrets.${psiProtected.secretNames.reader}.path;
        policies = [ psiProtected.accessKeys.reader ];
      }
      {
        name = psiProtected.accessKeys.pruner;
        secretKeyFile = config.sops.secrets.${psiProtected.secretNames.pruner}.path;
        policies = [ psiProtected.accessKeys.pruner ];
      }
    ];
  };

  system.stateVersion = "25.05";
}
