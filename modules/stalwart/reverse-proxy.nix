{ config, ... }:
let
  publicDomain = "mail.sjanglab.org";
  httpPort = 8082;
in
{
  security.acme.certs.${publicDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
    reloadServices = [ "stalwart.service" ];
  };

  users.users.stalwart-mail.extraGroups = [ "nginx" ];

  services.nginx.virtualHosts.${publicDomain} = {
    forceSSL = true;
    useACMEHost = publicDomain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString httpPort}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}
