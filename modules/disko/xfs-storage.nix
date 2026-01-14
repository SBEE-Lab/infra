{
  lib,
  config,
  ...
}:
let
  cfg = config.disko.xfsStorage;
  inherit (lib) types mkOption;

  defaultXfsOptions = [
    "defaults"
    "noatime"
    "largeio"
    "inode64"
    "allocsize=64m"
    "filestreams"
    "logbsize=256k"
  ];

  mkXfsDisk = diskName: diskId: {
    type = "disk";
    device = diskId;
    content = {
      type = "gpt";
      partitions = {
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "xfs";
            mountpoint = "/storage/${diskName}";
            mountOptions = cfg.xfsOptions;
          };
        };
      };
    };
  };
in
{
  options.disko.xfsStorage = {
    disks = mkOption {
      type = types.attrsOf types.str;
    };
    xfsOptions = mkOption {
      type = types.listOf types.str;
      default = defaultXfsOptions;
    };
  };
  config = {
    disko.devices.disk = builtins.mapAttrs mkXfsDisk cfg.disks;
  };
}
