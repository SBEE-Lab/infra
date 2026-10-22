# SjangLab Apps dashboard
# Host-side Gatus checks beside external Blackbox probes: outside down with the
# inside up points at ingress or network; inside down points at the app itself.
# Access side-effects live in the Security & audit dashboard.
{ datasources }:
let
  inherit (datasources) prometheus;
  p = import ./panels.nix { inherit datasources; };
  inherit (p) grid;
in
{
  uid = "sjanglab-apps";
  title = "SjangLab Apps";
  tags = [
    "infra"
    "apps"
  ];
  timezone = "browser";
  schemaVersion = 41;
  version = 2;
  refresh = "30s";
  time = {
    from = "now-24h";
    to = "now";
  };
  templating.list = [ ];
  annotations.list = [ ];
  panels = [
    {
      id = 1;
      title = "Inside: host checks (Gatus)";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 9;
        w = 12;
        x = 0;
        y = 0;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      transformations = [
        { id = "labelsToFields"; }
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              __name__ = true;
              key = true;
              type = true;
            };
            indexByName = {
              group = 0;
              name = 1;
              Value = 2;
              gatus_results_endpoint_success = 2;
            };
            renameByName = {
              Value = "status";
              gatus_results_endpoint_success = "status";
            };
          };
        }
      ];
      fieldConfig.defaults.mappings = [
        {
          type = "value";
          options = {
            "0" = {
              text = "DOWN";
              color = "red";
            };
            "1" = {
              text = "UP";
              color = "green";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "last_over_time(gatus_results_endpoint_success[5m])";
          instant = true;
          format = "table";
        }
      ];
    }
    {
      id = 2;
      title = "Endpoint success over time";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 9;
      };
      fieldConfig.defaults = {
        min = 0;
        max = 1;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "avg by (group, name) (gatus_results_endpoint_success)";
          legendFormat = "{{group}}/{{name}}";
        }
      ];
    }
    {
      id = 5;
      title = "Outside: external probes (Blackbox)";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 9;
        w = 12;
        x = 12;
        y = 0;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      transformations = [
        { id = "labelsToFields"; }
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              __name__ = true;
            };
            indexByName = {
              probe_scope = 0;
              service = 1;
              instance = 2;
              job = 3;
              Value = 4;
              probe_success = 4;
            };
            renameByName = {
              probe_scope = "scope";
              Value = "status";
              probe_success = "status";
            };
          };
        }
      ];
      fieldConfig.defaults.mappings = [
        {
          type = "value";
          options = {
            "0" = {
              text = "DOWN";
              color = "red";
            };
            "1" = {
              text = "UP";
              color = "green";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''probe_success{job=~"blackbox_(http|tailnet_http|tcp)"}'';
          instant = true;
          format = "table";
        }
      ];
    }
    (p.row {
      id = 6;
      title = "Nextcloud";
      y = 17;
    })
    (p.timeseries {
      id = 7;
      title = "PHP-FPM worker crashes";
      ds = "prometheus";
      pos = grid 0 18 8 8;
      bars = true;
      targets = [
        {
          expr = "sum by (host) (increase(nextcloud_phpfpm_worker_crashes_total[10m]))";
          legend = "{{host}}";
        }
      ];
    })
    (p.timeseries {
      id = 8;
      title = "Public 5xx by service";
      ds = "prometheus";
      pos = grid 8 18 8 8;
      bars = true;
      targets = [
        {
          expr = "sum by (service) (increase(nginx_public_server_errors_total[10m]))";
          legend = "{{service}}";
        }
      ];
    })
    (p.logs {
      id = 9;
      title = "Nextcloud warnings and PHP-FPM";
      description = "App log level 2 and above plus the php-fpm journal; info logs are not collected.";
      pos = grid 16 18 8 8;
      expr = ''{log_type="nextcloud"}'';
    })
  ];
}
