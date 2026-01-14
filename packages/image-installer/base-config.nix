{
  lib,
  pkgs,
  ...
}:
let
  mulattaKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkKJdIzvxlWcry+brNiCGLBNkxrMxFDyo1anE4xRNkL"
  ];
in
{
  system.stateVersion = "25.05";

  networking.firewall.enable = false;

  networking.usePredictableInterfaceNames = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  services.openssh = {
    enable = true;
    ports = [ 10022 ];
    settings = {
      PermitRootLogin = "yes";
    };
  };

  users.users.root = {
    openssh.authorizedKeys.keys = lib.mkAfter mulattaKeys;
  };

  documentation.enable = false;
  documentation.nixos.options.warningsAreErrors = false;

  environment.systemPackages = with pkgs; [
    diskrsync
    partclone
    curl
    gitMinimal # for flakes
    jq
  ];

  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
}
