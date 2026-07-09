# L7 split for the Loki and Prometheus query/ingest ports.
#
# Loki and Prometheus serve ingest and query on a single port, so an L4
# firewall cannot separate them. Instead both bind to localhost and these
# nginx listeners re-expose exactly the ingest paths on wg-admin. Fleet
# agents keep pushing to the same wg-admin endpoints they always used;
# every read/query path returns 403 to peers and is reachable only by
# rho-local consumers (Grafana, the ruler, the correlators) over 127.0.0.1.
{ config, ... }:
let
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
in
{
  services.nginx = {
    enable = true;
    virtualHosts = {
      loki-ingest = {
        serverName = "loki-ingest.internal";
        listen = [
          {
            addr = wgAdminAddr;
            port = 3100;
          }
        ];
        locations = {
          "= /loki/api/v1/push" = {
            proxyPass = "http://127.0.0.1:3100";
            # Vector batches up to 1 MiB pre-encoding; Loki permits 16 MB
            # bursts. nginx defaults to 1 MiB, which would 413 large batches.
            extraConfig = ''
              client_max_body_size 16m;
              access_log off;
            '';
          };
          # Vector loki sinks health-check GET /ready on the endpoint.
          "= /ready" = {
            proxyPass = "http://127.0.0.1:3100";
            extraConfig = "access_log off;";
          };
          "/" = {
            extraConfig = "return 403;";
          };
        };
      };

      prometheus-ingest = {
        serverName = "prometheus-ingest.internal";
        listen = [
          {
            addr = wgAdminAddr;
            port = 9090;
          }
        ];
        locations = {
          "= /api/v1/write" = {
            proxyPass = "http://127.0.0.1:9090";
            extraConfig = ''
              client_max_body_size 16m;
              access_log off;
            '';
          };
          "/" = {
            extraConfig = "return 403;";
          };
        };
      };
    };
  };

  # 3100/9090 stay open on wg-admin, now terminated by nginx above.
  networking.firewall.interfaces."wg-admin".allowedTCPPorts = [
    3100
    9090
  ];
}
