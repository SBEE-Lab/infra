# https://github.com/TUM-DSE/doctor-cluster-config/tree/4702b65ba00ccaf932fa87c71eee5a5b584896ab/modules/users/default.nix
{
  lib,
  config,
  ...
}: {
  imports = [
    # system monitoring / backup infra
    ./admins.nix
    # Ph.D./MS who use GPU Compute Node (psi)
    ./researchers.nix
    # BS who use tau/rho
    ./students.nix

    ./extra-user-options.nix
  ];

  config = {
    programs.fish.enable = true;
    programs.zsh.enable = true;

    services.userborn.enable = true;

    systemd.tmpfiles.rules = builtins.map (n: "R /home/${n} - - - - -") config.users.deletedUsers;

    assertions = lib.flatten (
      lib.mapAttrsToList (name: user: {
        assertion =
          user.isSystemUser
          || lib.all (
            group: group != "student" || group != "admin" || group != "researcher"
          )
          user.extraGroups;
        message = ''
          User ${name} is not in the admin, researcher, student group.
          Please add them to the correct group.
        '';
      })
      config.users.users
    );
  };
}
