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

  services.harmonia.cache = {
    enable = true;

    signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];

    settings = {
      bind = "0.0.0.0:${toString port}";
      priority = 50;
    };
  };

  sops.secrets.harmonia-sign-key = {
    sopsFile = ./secrets.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  # Allow nix-daemon to read store for harmonia
  nix.settings.allowed-users = [ "harmonia" ];

  # Open firewall on wireguard interface
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ port ];
}
