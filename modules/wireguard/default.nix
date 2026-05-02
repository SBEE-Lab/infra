{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./machines.nix
    ./admin-access.nix
  ];

  options = with lib; {
    networking.sbee.wireguard = mkOption {
      type =
        with types;
        attrsOf (submodule {
          options = {
            interface = mkOption {
              type = str;
              description = "WireGuard interface name";
            };
            port = mkOption {
              type = int;
              description = "WireGuard listen port";
            };
            address = mkOption {
              type = str;
              description = "WireGuard interface address with CIDR";
            };
            peers = mkOption {
              type = listOf attrs;
              default = [ ];
              description = "WireGuard peer configurations";
            };
          };
        });
      default = { };
      description = "WireGuard network configurations";
    };
  };

  config = {
    sops.secrets = {
      "wg-admin-key" = {
        mode = "0400";
        owner = "systemd-network";
        group = "systemd-network";
        restartUnits = [ "systemd-networkd.service" ];
      };
    };

    # sops must place WireGuard private key before networkd tries to create the netdev
    systemd.services.systemd-networkd = {
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
    };

    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];
  };
}
