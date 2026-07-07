{
  config,
  ...
}:
let
  inherit (config.networking.sbee) currentHost hosts;
  authentikAuth = import ../authentik/nginx-locations.nix { inherit hosts; };
  loggingDomain = "logging.sjanglab.org";
  certDir = "/var/lib/acme/${loggingDomain}";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      domain = loggingDomain;
      user = "acme-sync-logging";
    }
  ];

  services.nginx = {
    enable = true;

    virtualHosts.${loggingDomain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations = authentikAuth.locations // {
        "/" = {
          proxyPass = "http://${currentHost.wg-admin}:3000";
          extraConfig = authentikAuth.protectLocation + ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        "/api/live/" = {
          proxyPass = "http://${currentHost.wg-admin}:3000";
          proxyWebsockets = true;
          extraConfig = authentikAuth.protectLocation + ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        "= /alertmanager" = {
          return = "301 /alertmanager/";
        };
        "/alertmanager/" = {
          proxyPass = "http://${currentHost.wg-admin}:9093";
          extraConfig = authentikAuth.protectLocation + ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Accept-Encoding "";
            sub_filter_once on;
            sub_filter_types text/html;
            sub_filter "JSON.parse(localStorage.getItem('firstDayOfWeek'))" "JSON.parse(localStorage.getItem('firstDayOfWeek') || '\"Monday\"')";
          '';
        };
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
