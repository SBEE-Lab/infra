# R     /dir/to/remove/recursively - - - - -
{
  lib,
  config,
  ...
}: {
  # Create scratch space per user on dedicated high-speed storage.
  # The scratch space is for temporary/intermediate data (not backed up).
  # /scratch is mounted on the RAID array (8TB x2 SSD RAID0 on psi).
  # Use this for I/O intensive workloads, benchmarks, and temporary files.
  systemd.tmpfiles.rules = let
    loginUsers = lib.filterAttrs (_n: v: v.isNormalUser || v.name == "root") config.users.users;
  in
    (lib.mapAttrsToList (n: _v: "d /scratch/${n} 0755 ${n} users -") loginUsers)
    ++ (builtins.map (n: "R /scratch/${n} - - - - -") config.users.deletedUsers);
}
