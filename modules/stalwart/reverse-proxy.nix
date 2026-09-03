_:
let
  publicDomain = "mail.sjanglab.org";
  httpPort = 8082;
in
{
  services.sbee.nginx.edgeVhosts.${publicDomain}.reloadServices = [ "stalwart.service" ];

  users.users.stalwart-mail.extraGroups = [ "nginx" ];

  services.nginx.virtualHosts.${publicDomain} = {
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
