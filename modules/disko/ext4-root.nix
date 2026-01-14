{
  lib,
  config,
  ...
}:
{
  options = {
    disko.rootDisk = lib.mkOption {
      type = lib.types.str;
      default = "/dev/vda";
      description = "The device to use for the disk.";
    };
  };
  config = {
    disko.devices = {
      disk = {
        main = {
          device = config.disko.rootDisk;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "512M";
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
                  format = "ext4";
                  mountpoint = "/";
                  mountOptions = [
                    "defaults"
                    "noatime"
                    "errors=remount-ro"
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
