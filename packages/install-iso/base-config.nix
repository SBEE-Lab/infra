{
  lib,
  pkgs,
  ...
}:
{
  system.stateVersion = "25.05";

  networking.firewall.enable = false;

  networking.usePredictableInterfaceNames = false;
  systemd.network.enable = true;
  networking.useNetworkd = true;

  systemd.network.networks = {
    "10-ethernet".extraConfig = ''
      [Match]
      Type = ether

      [Network]
      Address = 10.80.169.64/24
      Gateway = 10.80.169.254
      DNS = 117.16.191.6
      DNS = 168.126.63.1
    '';
  };

  imports = [
    ../../modules/users
  ];

  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets.root-password-hash = { };

  documentation.enable = false;
  documentation.nixos.options.warningsAreErrors = false;

  environment.systemPackages = with pkgs; [
    diskrsync
    partclone
    curl
    dnsutils
    gitMinimal # for flakes
    htop
    jq
    tmux
  ];

  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
}
