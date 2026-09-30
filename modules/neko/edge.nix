_:
let
  domain = "neko.sjanglab.org";
  mediaPort = 59000;
  rhoNaruIPv4 = "10.208.0.4";
in
{
  imports = [ ../monitoring/audit/nginx-access-logs.nix ];

  services.sbee.nginx.edgeVhosts.${domain} = { };
  services.sbee.nginxAccessLogs.services.${domain} = "neko";

  # Avoid systemd-resolved negative caching while the DNS-01 record is transient.
  security.acme.certs.${domain}.dnsResolver = "1.1.1.1:53";

  services.nginx = {
    commonHttpConfig = ''
      limit_req_zone $binary_remote_addr zone=neko_public:10m rate=20r/s;
      limit_conn_zone $binary_remote_addr zone=neko_public_per_ip:10m;
    '';

    virtualHosts.${domain} = {
      extraConfig = ''
        access_log /var/log/nginx/access-audit/neko.log nginx_access_json;
        client_header_timeout 15s;
        limit_conn neko_public_per_ip 20;
        limit_conn_status 429;
      '';

      locations."/" = {
        proxyPass = "https://rho.n:8082";
        proxyWebsockets = true;
        extraConfig = ''
          limit_req zone=neko_public burst=60 nodelay;
          limit_req_status 429;
          proxy_set_header Host ${domain};
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Host ${domain};
          proxy_set_header X-Forwarded-Proto https;
          proxy_ssl_server_name on;
          proxy_ssl_name rho.n;
          # Naru authenticates and encrypts this hop; rho currently omits the
          # Dure intermediate certificate required for nginx chain validation.
          proxy_ssl_verify off;
          proxy_connect_timeout 5s;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          proxy_buffering off;
        '';
      };
    };

    streamConfig = ''
      upstream neko_media_tcp {
        server ${rhoNaruIPv4}:${toString mediaPort};
      }

      upstream neko_media_udp {
        server ${rhoNaruIPv4}:${toString mediaPort};
      }

      server {
        listen ${toString mediaPort};
        proxy_connect_timeout 5s;
        proxy_timeout 1h;
        proxy_socket_keepalive on;
        proxy_pass neko_media_tcp;
      }

      server {
        listen ${toString mediaPort} udp reuseport;
        proxy_timeout 1h;
        proxy_pass neko_media_udp;
      }
    '';
  };

  networking.firewall = {
    allowedTCPPorts = [ mediaPort ];
    allowedUDPPorts = [ mediaPort ];
  };
}
