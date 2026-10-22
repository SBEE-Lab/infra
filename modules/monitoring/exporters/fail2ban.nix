# fail2ban ban counts, so SSH brute-force pressure is visible without parsing its log.
{ config, lib, ... }:
let
  host = config.networking.hostName;
  exporter = config.services.prometheus.exporters.fail2ban;
in
{
  config = lib.mkIf config.services.fail2ban.enable {
    services.prometheus.exporters.fail2ban.enable = true;

    services.vector.settings = {
      sources.fail2ban_metrics = {
        type = "prometheus_scrape";
        endpoints = [ "http://${exporter.host}:${toString exporter.port}/metrics" ];
        scrape_interval_secs = 60;
      };
      transforms.fail2ban_metrics_tagged = {
        type = "remap";
        inputs = [ "fail2ban_metrics" ];
        source = ''.tags.host = "${host}"'';
      };
      sinks.${if host == "rho" then "system_metrics_local" else "system_metrics_remote"}.inputs = [
        "fail2ban_metrics_tagged"
      ];
    };
  };
}
