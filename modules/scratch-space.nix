# R     /dir/to/remove/recursively - - - - -
{
  lib,
  config,
  ...
}: {
  # Create scratch space on dedicated high-speed storage.
  # The scratch space is for temporary/intermediate data (not backed up).
  # /scratch is mounted on the RAID array (8TB x2 SSD RAID0 on psi).
  #
  # Structure:
  #   /scratch/<user>/     - Per-user workspace for I/O intensive workloads
  #   /scratch/shared/     - Shared databases and indices (alphafold3, uniref, etc.)
  systemd.tmpfiles.rules = let
    loginUsers = lib.filterAttrs (_n: v: v.isNormalUser || v.name == "root") config.users.users;
  in
    [
      # Shared space for databases and indices (not backed up, re-downloadable)
      "d /scratch/shared 0755 root users -"
      "d /scratch/shared/databases 0755 root users -"
    ]
    ++ (lib.mapAttrsToList (n: _v: "d /scratch/${n} 0755 ${n} users -") loginUsers)
    ++ (builtins.map (n: "R /scratch/${n} - - - - -") config.users.deletedUsers);
}
