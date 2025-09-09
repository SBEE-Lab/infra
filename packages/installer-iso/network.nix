{
  systemd.network.networks = {
    "10-ethernet".extraConfig = ''
      [Match]
      Type = ether

      [Network]
      Address = 10.80.169.64/24
      Gateway = 10.80.169.254
      DNS = 117.16.191.6
      DNS = 168.126.63.1
    '';
  };
}
