{ config, ... }:
let
  domain = "upterm.sjanglab.org";
  port = 2323;
in
{
  imports = [
    ../acme
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

  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;
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
