# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃                                  NOTICE                                    ┃
# ┃ 1. PLEASE FOLLOW THE COMMENTS                                              ┃
# ┃ 2. DO NOT UNCOMMENT AND MODIFY THE COMMENTS (JUST USE THEM AS TEMPLATES)   ┃
# ┃ 3. DO NOT MODIFY `extraGroups`, `users.deletedUsers`                       ┃
# ┃ 4. ALL THE COMMENTS SHOULD BE LOCATED AT THE END OF THE CONTENTS.          ┃
# ┃    PLEASE WRITE YOUR ACCOUNT INFO ON TOP OF THE COMMENTS                   ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
let
  extraGroups = [
    "docker"
    "researcher"
    "input"
  ];
  # ADD YOUR SSH PUBLIC KEY FOR SERVER CONNECTION
  # testUserKeys = [
  # "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  # ];
in
{
  # ADD YOUR USER ACCOUNT
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
