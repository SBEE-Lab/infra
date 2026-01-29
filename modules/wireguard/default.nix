{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.networking.sbee.currentHost;
  inherit (config.networking.sbee) others;

  hasTag = host: tag: builtins.elem tag (host.tags or [ ]);
  currentHasTag = tag: hasTag cfg tag;

  mkPeer =
    interface: port: hostName: host:
    lib.filterAttrs (_n: v: v != null) {
      PublicKey = builtins.readFile (./keys + "/${hostName}_${interface}");
      Endpoint =
        if ((currentHasTag "public-ip") && (hasTag host "nat-behind")) then
          null
        else
          "${host.ipv4}:${builtins.toString port}";
      AllowedIPs = [ "${host.${interface}}/32" ];
      PersistentKeepalive = 25;
    };
in
{
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
              description = "WireGuard peer configurations";
            };
          };
        });
      default = { };
      description = "WireGuard network configurations";
    };
  };
  config = {
    # wireguard configuration for current host
    networking.sbee.wireguard = {
      wg-admin = {
        interface = "wg-admin";
        port = 51820;
        address = "${cfg.wg-admin}/24";
        peers = lib.mapAttrsToList (mkPeer "wg-admin" 51820) others;
      };
    };

    sops.secrets = {
      "wg-admin-key" = {
        mode = "0400";
        owner = "systemd-network";
        group = "systemd-network";
      };
    };

    environment.systemPackages = with pkgs; [
      wireguard-tools
    ];
  };
}
