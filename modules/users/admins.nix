{
  config,
  lib,
  ...
}: let
  seungwonKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkKJdIzvxlWcry+brNiCGLBNkxrMxFDyo1anE4xRNkL"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMzkxPcb7+kD38k1G1erxSOg4TTAcYXkMQo1rw0CYEA"
  ];

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

    root = {
      hashedPasswordFile = lib.mkIf config.users.withSops config.sops.secrets.root-password-hash.path;
      openssh.authorizedKeys.keys = seungwonKeys;
    };
  };

  nix.settings.trusted-users = [
    "seungwon"
  ];
}
