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
        system = {
          device = config.disko.rootDisk;
          type = "disk";
          content = {
            type = "gpt";
            partitions.ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            partitions.zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
      zpool = {
        zroot = {
          type = "zpool";
          rootFsOptions = {
            compression = "lz4";
            xattr = "sa";
            atime = "off";
            acltype = "posixacl";
            "com.sun:auto-snapshot" = "false";
          };
          options.ashift = "12";

          datasets = {
            "root" = {
              type = "zfs_fs";
            };
            "root/nixos" = {
              type = "zfs_fs";
              mountpoint = "/";
              options."com.sun:auto-snapshot" = "true";
            };
            "root/home" = {
              type = "zfs_fs";
              mountpoint = "/home";
              options."com.sun:auto-snapshot" = "true";
            };
            "root/tmp" = {
              type = "zfs_fs";
              mountpoint = "/tmp";
              options = {
                sync = "disabled";
                "com.sun:auto-snapshot" = "false";
              };
            };
          };
        };
      };
    };
  };
}
