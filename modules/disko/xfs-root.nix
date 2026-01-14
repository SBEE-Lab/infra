{
  lib,
  config,
  ...
}:
{
  options = {
    disko.rootDisk = lib.mkOption {
      type = lib.types.str;
      default = "/dev/nvme0n1";
      description = "The device to use for the disk.";
    };
  };
  config = {
    disko.devices = {
      disk = {
        system = {
          device = config.disko.rootDisk;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                type = "EF02";
                size = "1M";
              };
              ESP = {
                type = "EF00";
                size = "1G";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [
                    "defaults"
                    "umask=0077"
                  ];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "xfs";
                  mountpoint = "/";
                  mountOptions = [
                    "defaults"
                    "noatime"
                    "largeio"
                    "inode64"
                    "allocsize=16m"
                    "pquota"
                    "uquota"
                    "gquota"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
