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
      wg-mgnt = {
        interface = "wg-mgnt";
        port = 51820;
        address = "${cfg.wg-mgnt}/24";
        peers = lib.mapAttrsToList (mkPeer "wg-mgnt" 51820) others;
      };
      wg-serv = {
        interface = "wg-serv";
        port = 51821;
        address = "${cfg.wg-serv}/24";
        peers = lib.mapAttrsToList (mkPeer "wg-serv" 51821) others;
      };
    };

    sops.secrets = {
      "wg-mgnt-key" = {
        mode = "0400";
        owner = "systemd-network";
        group = "systemd-network";
      };
      "wg-serv-key" = {
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
