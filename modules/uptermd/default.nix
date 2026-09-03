_:
let
  domain = "upterm.sjanglab.org";
  port = 2323;
in
{
  services.sbee.nginx.edgeVhosts.${domain} = { };
  imports = [
    ../gatus/check.nix
  ];

  services.uptermd = {
    enable = true;
    openFirewall = true;
    inherit port;
    listenAddress = "0.0.0.0";
    extraFlags = [
      "--hostname"
      domain
    ];
  };

  services.nginx.virtualHosts.${domain} = {
    locations."/".root = ./site;
  };

  gatusCheck.pull = [
    {
      name = "Upterm";
      url = "tcp://${domain}:${toString port}";
      group = "platform";
      conditions = [ "[CONNECTED] == true" ];
    }
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
