# A host that imports this module needs to set this:
# Replace device names with the disks you want to use
#  disko.devices.disk.storage1.device = "/dev/disk/by-id/nvme-SAMSUNG_MZQL23T8HCLS-00A07_S64HNT0X115369";
#  disko.devices.disk.storage2.device = "/dev/disk/by-id/nvme-SAMSUNG_MZQL23T8HCLS-00A07_S64HNT0X115369";
{
  disko.devices = {
    disk = {
      storage1 = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storageDisk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zstorage";
              };
            };
          };
        };
      };

      storage2 = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storageDisk = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zstorage";
              };
            };
          };
        };
      };
    };

    zpool = {
      zstorage = {
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
          "data" = {
            type = "zfs_fs";
            mountpoint = "/mnt/storage";
            options."com.sun:auto-snapshot" = "true";
          };
        };
      };
    };
  };
}
