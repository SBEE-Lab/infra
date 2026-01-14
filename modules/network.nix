{
  config,
  lib,
  ...
}:
let
  cfg = config.networking.sbee.currentHost;
  wg = config.networking.sbee.wireguard;

  hasTag = tag: builtins.elem tag (cfg.tags or [ ]);

  subnet = if hasTag "vps-network" then "23" else "24";
  nameservers =
    if hasTag "kren-dns" then
      [
        "117.16.191.6"
        "168.126.63.1"
      ]
    else
      [
        "8.8.8.8"
        "1.1.1.1"
      ];
in
{
  imports = [ ./wireguard ];

  config = {
    # use networkd
    networking.dhcpcd.enable = false;
    systemd.network.enable = true;

    # add an entry to /etc/hosts for each host
    networking.extraHosts = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: host: ''
        ${host.ipv4} ${name}
      '') config.networking.sbee.others
    );

    boot.initrd.systemd.network.networks."10-ethernet" = config.systemd.network.networks."10-ethernet";

    # we only manage our in-house instances
    # provisioned instances are managed by provider
    systemd.network.networks = {
      "10-ethernet" = {
        matchConfig.MACAddress = cfg.mac;
        address = [ "${cfg.ipv4}/${subnet}" ];
        routes = [ { Gateway = "${cfg.gateway}"; } ];
        dns = nameservers;
      };
    }
    // lib.mapAttrs (_: wgCfg: {
      matchConfig.Name = wgCfg.interface;
      address = [ wgCfg.address ];
    }) wg;
    systemd.network.netdevs = lib.mapAttrs (_: wgCfg: {
      netdevConfig = {
        Name = wgCfg.interface;
        Kind = "wireguard";
      };
      wireguardConfig = {
        PrivateKeyFile = config.sops.secrets."${wgCfg.interface}-key".path;
        ListenPort = wgCfg.port;
      };
      wireguardPeers = wgCfg.peers;
    }) wg;

    networking.firewall = {
      allowedUDPPorts = lib.mapAttrsToList (_: wgCfg: wgCfg.port) wg;
      trustedInterfaces = lib.mapAttrsToList (_: wgCfg: wgCfg.interface) wg;
    };
  };
}
