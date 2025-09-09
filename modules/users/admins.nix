{
  config,
  lib,
  ...
}:
let
  mulattaKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkKJdIzvxlWcry+brNiCGLBNkxrMxFDyo1anE4xRNkL"
  ];

  extraGroups = [
    "wheel"
    "docker"
    "admin"
    "input"
  ];
in
{
  users.users = {
    # Seungwon Lee
    mulatta = {
      isNormalUser = true;
      home = "/home/mulatta";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/fish";
      uid = 1000;
      openssh.authorizedKeys.keys = mulattaKeys;
    };

    root = {
      hashedPasswordFile = lib.mkIf config.users.withSops config.sops.secrets.root-password-hash.path;
      openssh.authorizedKeys.keys = mulattaKeys;
    };
  };

  nix.settings.trusted-users = [
    "mulatta"
  ];
}
