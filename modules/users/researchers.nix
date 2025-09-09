{ ... }:
let
  # testUserKeys = ["ssh-ed25519 .."]; # ssh public key for user
  extraGroups = [
    "docker"
    "researcher"
    "input"
  ];
in
{
  # users.users = {
  #   # specify your real name in comments
  #   testUsers = {
  #     isNormalUser = true;
  #     home = "/home/testUser"; # specify home directory paths
  #     inherit extraGroups;
  #     shell = "/run/current-system/sw/bin/bash"; # specify your favorite shell
  #     uid = 3000; # uid should be unique
  #     allowedHosts = []; # specify allowed host (ex: "rho")
  #     openssh.authorizedKeys.keys = testUserKeys;
  #     expires = "2026-08-31"; # for researcher group, expiration must be specified
  #   };
  # };

  # DANGER ZONE!
  # Make sure all data is backed up before adding user names here. This will
  # delete all data of the associated user
  users.deletedUsers = [ ];
}
