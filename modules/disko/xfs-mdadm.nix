# XFS RAID0 storage module (striping for maximum capacity)
#
# Usage in host config:
#   disko.xfsMdadm.arrays.workspace = {
#     disks.ssd1 = "/dev/disk/by-id/nvme-...";
#     disks.ssd2 = "/dev/disk/by-id/nvme-...";
#     mountpoint = "/workspace";
#     xfsOptions = [ "defaults" "noatime" ... ];
#   };
{
  lib,
  config,
  ...
}:
let
  cfg = config.disko.xfsMdadm;
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;

  defaultXfsOptions = [
    "defaults"
    "noatime"
    "inode64"
    "logbsize=256k"
  ];

  arrayType = types.submodule {
    options = {
      disks = mkOption {
        type = types.attrsOf types.str;
        description = "Disks to include in the RAID array (by-id paths recommended)";
        example = {
          ssd1 = "/dev/disk/by-id/nvme-Samsung_SSD_...";
          ssd2 = "/dev/disk/by-id/nvme-Samsung_SSD_...";
        };
      };

      mountpoint = mkOption {
        type = types.str;
        description = "Mount point for the RAID array";
        example = "/workspace";
      };

      xfsOptions = mkOption {
        type = types.listOf types.str;
        default = defaultXfsOptions;
        description = "XFS mount options (overrides defaults)";
      };

      extraXfsOptions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Additional XFS mount options (appended to defaults)";
      };
    };
  };

  # Generate disk configurations for an array
  mkArrayDisks =
    arrayName: arrayCfg:
    builtins.mapAttrs (_diskName: diskPath: {
      type = "disk";
      device = diskPath;
      content = {
        type = "gpt";
        partitions = {
          mdraid = {
            size = "100%";
            content = {
              type = "mdraid";
              name = arrayName;
            };
          };
        };
      };
    }) arrayCfg.disks;

  # Generate mdadm configuration for an array
  mkArrayMdadm = arrayName: arrayCfg: {
    ${arrayName} = {
      type = "mdadm";
      level = 0;
      content = {
        type = "filesystem";
        format = "xfs";
        inherit (arrayCfg) mountpoint;
        mountOptions = arrayCfg.xfsOptions ++ arrayCfg.extraXfsOptions;
      };
    };
  };

  # Merge all disk configs from all arrays
  allDisks = lib.foldl' (acc: name: acc // mkArrayDisks name cfg.arrays.${name}) { } (
    builtins.attrNames cfg.arrays
  );

  # Merge all mdadm configs
  allMdadm = lib.foldl' (acc: name: acc // mkArrayMdadm name cfg.arrays.${name}) { } (
    builtins.attrNames cfg.arrays
  );
in
{
  options.disko.xfsMdadm = {
    enable = mkEnableOption "XFS RAID1 storage arrays";

    arrays = mkOption {
      type = types.attrsOf arrayType;
      default = { };
      description = "RAID1 array configurations";
    };
  };

  config = mkIf (cfg.enable && cfg.arrays != { }) {
    # Enable mdadm RAID support
    boot.swraid = {
      enable = true;
      mdadmConf = "MAILADDR root";
    };

    disko.devices = {
      disk = allDisks;
      mdadm = allMdadm;
    };
  };
}
