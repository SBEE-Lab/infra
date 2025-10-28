# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃                                  NOTICE                                    ┃
# ┃ 1. PLEASE FOLLOW THE COMMENTS                                              ┃
# ┃ 2. DO NOT UNCOMMENT AND MODIFY THE COMMENTS (JUST USE THEM AS TEMPLATES)   ┃
# ┃ 3. DO NOT MODIFY `extraGroups`, `users.deletedUsers`                       ┃
# ┃ 4. ALL THE COMMENTS SHOULD BE LOCATED AT THE END OF THE CONTENTS.          ┃
# ┃    PLEASE WRITE YOUR ACCOUNT INFO ON TOP OF THE COMMENTS                   ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
{
  config,
  lib,
  ...
}: let
  seungwonKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkKJdIzvxlWcry+brNiCGLBNkxrMxFDyo1anE4xRNkL"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMzkxPcb7+kD38k1G1erxSOg4TTAcYXkMQo1rw0CYEA"
  ];

  # ADD YOUR SSH PUBLIC KEY FOR SERVER CONNECTION
  # testUserKeys = [
  # "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  # ];

  extraGroups = [
    "wheel"
    "docker"
    "admin"
    "input"
  ];
in {
  users.users = {
    # Seungwon Lee
    seungwon = {
      isNormalUser = true;
      home = "/home/seungwon";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/fish";
      uid = 1000;
      openssh.authorizedKeys.keys = seungwonKeys;
    };

    # ADD YOUR USER ACCOUNT
    # users.users = {
    #   # specify your real name (full name) in comments
    #   testUsers = {
    #     isNormalUser = true;
    #     home = "/home/testUser"; # specify home directory paths
    #     inherit extraGroups;
    #     shell = "/run/current-system/sw/bin/bash"; # specify your favorite shell
    #     uid = 3000; # uid should be unique
    #     allowedHosts = []; # specify allowed host (ex: "rho")
    #     openssh.authorizedKeys.keys = testUserKeys;
    #     expires = "2026-08-31"; # for student group, expiration must be specified
    #   };
    # };

    root = {
      hashedPasswordFile = lib.mkIf config.users.withSops config.sops.secrets.root-password-hash.path;
      openssh.authorizedKeys.keys = seungwonKeys;
    };
  };

  nix.settings.trusted-users = [
    "seungwon"
  ];
}
