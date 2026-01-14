# R     /dir/to/remove/recursively - - - - -
{
  lib,
  config,
  ...
}:
{
  # Create project space per user on local rootfs.
  # The project space is for longer-term working data (backed up).
  # /project is stored on the local rootfs (4TB SSD).
  systemd.tmpfiles.rules =
    let
      loginUsers = lib.filterAttrs (_n: v: v.isNormalUser || v.name == "root") config.users.users;
    in
    (lib.mapAttrsToList (n: _v: "d /project/${n} 0755 ${n} users -") loginUsers)
    ++ (builtins.map (n: "R /project/${n} - - - - -") config.users.deletedUsers);
}
