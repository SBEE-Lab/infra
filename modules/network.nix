{
  config,
  lib,
  ...
}:
let
  cfg = config.networking.sbee.currentHost;
in
with lib;
{
  config = {
    # use networkd
    networking.dhcpcd.enable = false;
    systemd.network.enable = true;

    # add an entry to /etc/hosts for each host
    networking.extraHosts = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: host: ''
        ${host.ipv4} ${name}
      '') config.networking.sbee.hosts
    );

    boot.initrd.systemd.network.networks."10-ethernet" = config.systemd.network.networks."10-ethernet";

    # we only manage our in-house instances
    # provisioned instances are managed by provider
    systemd.network.networks."10-ethernet" = optionals (cfg.location != "terraform") {
      matchConfig.Type = "ether";
      address = [ "${cfg.ipv4}/24" ];
      routes = [ { Gateway = "${cfg.gateway}"; } ];
      dns = [
        "117.16.191.6"
        "168.126.63.1"
      ];
    };
  };
}
