{
  systemd.network.networks = {
    "10-ethernet".extraConfig = ''
      [Match]
      MACAddress = 9c:6b:00:9e:fa:de 9c:6b:00:9e:f8:ef
      [Network]
      Address = 10.80.169.64/24
      Gateway = 10.80.169.254
      DNS = 117.16.191.6
      DNS = 168.126.63.1
    '';
  };
}
