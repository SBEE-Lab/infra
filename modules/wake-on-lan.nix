{ config, ... }:
{
  systemd.network.links."10-wol" = {
    matchConfig = {
      MACAddress = config.networking.sbee.currentHost;
    };
  };
}
