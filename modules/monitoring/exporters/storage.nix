{ config, lib, ... }:
let
  host = config.networking.hostName;
  arrays = config.disko.xfsMdadm.arrays or { };
  enabled = arrays != { };
  devices = lib.unique (map (disk: disk.device) (lib.attrValues config.disko.devices.disk));
  node = config.services.prometheus.exporters.node;
  smartctl = config.services.prometheus.exporters.smartctl;
in
{
  config = lib.mkIf enabled {
    services.prometheus.exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        openFirewall = false;
        extraFlags = [ "--collector.disable-defaults" ];
        enabledCollectors = [ "mdadm" ];
      };
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
        openFirewall = false;
        inherit devices;
        maxInterval = "10m";
      };
    };

    services.vector.settings = {
      sources = {
        mdadm_metrics = {
          type = "prometheus_scrape";
          endpoints = [ "http://127.0.0.1:${toString node.port}/metrics" ];
          instance_tag = "instance";
          scrape_interval_secs = 60;
        };
        smartctl_metrics = {
          type = "prometheus_scrape";
          endpoints = [ "http://127.0.0.1:${toString smartctl.port}/metrics" ];
          instance_tag = "instance";
          scrape_interval_secs = 60;
        };
      };
      transforms.storage_metrics = {
        type = "remap";
        inputs = [
          "mdadm_metrics"
          "smartctl_metrics"
        ];
        source = ''.tags.host = "${host}"'';
      };
      sinks.${if host == "rho" then "system_metrics_local" else "system_metrics_remote"}.inputs = [
        "storage_metrics"
      ];
    };
  };
}
