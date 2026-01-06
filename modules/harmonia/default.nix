{
  config,
  pkgs,
  ...
}:
let
  port = 5000;
in
{
  environment.systemPackages = [ pkgs.harmonia ];

  services.harmonia = {
    enable = true;

    signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];

    settings = {
      bind = "0.0.0.0:${toString port}";
      priority = 50;
    };
  };

  sops.secrets.harmonia-sign-key = {
    sopsFile = ./secrets.yaml;
    owner = "harmonia";
  };

  # Allow nix-daemon to read store for harmonia
  nix.settings.allowed-users = [ "harmonia" ];

  # Open firewall on wireguard interface
  networking.firewall.interfaces.wg-serv.allowedTCPPorts = [ port ];
}
