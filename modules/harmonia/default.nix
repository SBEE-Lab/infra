{config, ...}: {
  services.harmonia = {
    enable = true;
    signKeyPaths = [config.sops.secrets.harmonia-private-key.path];
    settings = {
      bind = "${config.networking.sbee.hosts.psi.wg-serv}:5000";
      workers = 4;
      max_connection_rate = 256;
      priority = 30;
    };
  };

  networking.firewall = {
    allowedTCPPorts = [];
    interfaces.wg-serv.allowedTCPPorts = [5000];
  };

  networking.firewall.extraCommands = ''
    iptables -I INPUT -p tcp --dport 5000 ! -s 10.200.0.0/24 -j DROP
  '';

  sops.secrets.harmonia-private-key = {
    sopsFile = ./secrets.yaml;
    owner = "harmonia";
    group = "harmonia";
    mode = "0400";
  };
}
