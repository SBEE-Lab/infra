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
  dasolKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwTbesocbUbs0EL6OqVcsB4EqB7/fFGmwjaC5dX9cOD"
  ];
  hyeonahKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDhl8J3I9zHxpaIjcVbo/MooyfBki+d9YGhAv9fmR4bY"
  ];
  saebomKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFTnfSD0B4AixKN8CRjgISQkEkWZuXAtATTuWy4QoMGm"
  ];
  yoojinKey = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICxu/66OKP+sLMOxxQpxvSN0L0WlXKFTz30WwDlt758z"
  ];
  # ADD YOUR SSH PUBLIC KEY FOR SERVER CONNECTION
  # testUserKeys = [
  # "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA+bbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  # ];
in {
  users.users = {
    dasol = {
      isNormalUser = true;
      home = "/home/dasol";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/bash";
      uid = 3000;
      allowedHosts = ["psi"];
      openssh.authorizedKeys.keys = dasolKey;
      expires = "2030-03-31";
    };
    hyeonah = {
      isNormalUser = true;
      home = "/home/hyeonah";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/bash";
      uid = 3001;
      allowedHosts = ["psi"];
      openssh.authorizedKeys.keys = hyeonahKey;
      expires = "2028-03-31";
    };
    saebom = {
      isNormalUser = true;
      home = "/home/saebom";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/bash";
      uid = 3002;
      allowedHosts = ["psi"];
      openssh.authorizedKeys.keys = saebomKey;
      expires = "2030-08-31";
    };
    yoojin = {
      isNormalUser = true;
      home = "/home/yoojin";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/bash";
      uid = 3003;
      allowedHosts = ["psi"];
      openssh.authorizedKeys.keys = yoojinKey;
      expires = "2030-08-31";
    };

    # ADD YOUR USER ACCOUNT
    # specify your real name in comments
    # testUsers = {
    #   isNormalUser = true;
    #   home = "/home/testUser"; # specify home directory paths
    #   inherit extraGroups;
    #   shell = "/run/current-system/sw/bin/bash"; # specify your favorite shell
    #   uid = 3000; # uid should be unique
    #   allowedHosts = []; # specify allowed host (ex: "rho")
    #   openssh.authorizedKeys.keys = testUserKeys;
    #   expires = "2026-08-31"; # for student group, expiration must be specified
    # };
  };

  # DANGER ZONE!
  # Make sure all data is backed up before adding user names here. This will
  # delete all data of the associated user
  users.deletedUsers = [];
}
