{
  systemd.network.networks = {
    "10-ethernet".extraConfig = ''
      [Match]
      MACAddress = bc:fc:e7:52:e1:ab
      [Network]
      Address = 10.30.5.21/24
      Gateway = 10.30.5.254
      DNS = 117.16.191.6
      DNS = 168.126.63.1
    '';
  };
}
