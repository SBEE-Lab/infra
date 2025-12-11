# R     /dir/to/remove/recursively - - - - -
{
  lib,
  config,
  ...
}: {
  # Create workspace space on dedicated high-speed storage.
  # The workspace space is for temporary/intermediate data (not backed up).
  # /workspace is mounted on the RAID array (8TB x2 SSD RAID0 on psi).
  #
  # Structure:
  #   /workspace/<user>/     - Per-user workspace for I/O intensive workloads
  #   /workspace/shared/     - Shared databases and indices (alphafold3, uniref, etc.)
  systemd.tmpfiles.rules = let
    loginUsers = lib.filterAttrs (_n: v: v.isNormalUser || v.name == "root") config.users.users;
  in
    [
      # Shared space for databases and indices (not backed up, re-downloadable)
      "d /workspace/shared 0755 root users -"
      "d /workspace/shared/databases 0755 root users -"
    ]
    ++ (lib.mapAttrsToList (n: _v: "d /workspace/${n} 0755 ${n} users -") loginUsers)
    ++ (builtins.map (n: "R /workspace/${n} - - - - -") config.users.deletedUsers);
}
