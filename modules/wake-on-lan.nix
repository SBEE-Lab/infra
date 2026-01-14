{
  config,
  pkgs,
  lib,
  ...
}:
{
  systemd.network.links."10-wol" = lib.mkIf (config.networking.sbee.currentHost.mac != null) {
    matchConfig.MACAddress = config.networking.sbee.currentHost.mac;
    linkConfig = {
      WakeOnLan = "magic";
    };
  };

  environment.systemPackages = with pkgs; [
    ethtool
    wakeonlan
  ];

  # networking.firewall.extraCommands = ''
  #   iptabels -A INPUT -p udp --dport 9 -s 117.16.251.37 -j ACCEPT
  #   iptabels -A INPUT -p udp --dport 9 -j DROP
  # '';
}
