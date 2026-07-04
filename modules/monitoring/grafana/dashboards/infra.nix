# SjangLab Infrastructure overview dashboard (Grafana home)
# High-level health only; audit detail lives in access-audit.nix
{ datasources }:
let
  inherit (datasources) prometheus loki;

  # Stat tile counting audit events over the last 24h via an instant query
  auditStat =
    {
      id,
      title,
      x,
      expr,
    }:
    {
      inherit id title;
      type = "stat";
      datasource = loki;
      gridPos = {
        h = 4;
        w = 8;
        inherit x;
        y = 0;
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
      fieldConfig.defaults = {
        noValue = "0";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = null;
            }
            {
              color = "red";
              value = 1;
            }
          ];
        };
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          inherit expr;
          queryType = "instant";
          instant = true;
        }
      ];
    };
in
{
  uid = "sjanglab-infra";
  title = "SjangLab Infrastructure";
  tags = [
    "infra"
    "nixos"
  ];
  timezone = "browser";
  schemaVersion = 41;
  version = 1;
  refresh = "30s";
  time = {
    from = "now-6h";
    to = "now";
  };
  templating.list = [ ];
  annotations.list = [ ];
  panels = [
    (auditStat {
      id = 1;
      title = "SSH login failures (24h)";
      x = 0;
      expr = ''sum(count_over_time({log_type="ssh", event="login_failed"}[24h]))'';
    })
    (auditStat {
      id = 2;
      title = "Authentik login failures (24h)";
      x = 8;
      expr = ''sum(count_over_time({log_type="authentik", event="login_failed"}[24h]))'';
    })
    {
      id = 3;
      title = "Headscale nodes online";
      type = "stat";
      datasource = loki;
      gridPos = {
        h = 4;
        w = 8;
        x = 16;
        y = 0;
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
      fieldConfig.defaults = {
        noValue = "0";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "blue";
              value = null;
            }
          ];
        };
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          # Summary snapshots avoid double-counting repeated per-node inventory rows.
          expr = ''last_over_time({log_type="headscale_nodes", event="nodes_summary"} | json | unwrap online_count [10m])'';
          queryType = "instant";
          instant = true;
        }
      ];
    }
    {
      id = 4;
      title = "Host memory available";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 4;
      };
      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
        max = 100;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "100 * host_memory_available_bytes / host_memory_total_bytes";
          legendFormat = "{{host}}";
        }
      ];
    }
    {
      id = 5;
      title = "CPU busy";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 8;
        y = 4;
      };
      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
        max = 100;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''(1 - avg by (host) (rate(host_cpu_seconds_total{mode="idle"}[5m]))) * 100'';
          legendFormat = "{{host}}";
        }
      ];
    }
    {
      id = 6;
      title = "Root filesystem free";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 4;
      };
      fieldConfig.defaults = {
        unit = "percent";
        min = 0;
        max = 100;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''100 * host_filesystem_free_bytes{mountpoint="/"} / host_filesystem_total_bytes{mountpoint="/"}'';
          legendFormat = "{{host}}";
        }
      ];
    }
    {
      id = 7;
      title = "Gatus endpoints";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 12;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
        sortBy = [
          {
            displayName = "group";
            desc = false;
          }
        ];
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
      fieldConfig.defaults = {
        mappings = [
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
      };
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
      id = 8;
      title = "Prometheus targets";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 12;
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
              job = 0;
              instance = 1;
              Value = 2;
              up = 2;
            };
            renameByName = {
              Value = "status";
              up = "status";
            };
          };
        }
      ];
      fieldConfig.defaults = {
        mappings = [
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
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "up";
          instant = true;
          format = "table";
        }
      ];
    }
    {
      id = 9;
      title = "psi systemd status";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 20;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      transformations = [
        {
          id = "extractFields";
          options = {
            source = "Line";
            format = "json";
            replace = true;
            keepTime = true;
          };
        }
        {
          id = "organize";
          options = {
            excludeByName = {
              host = true;
              log_type = true;
              message = true;
            };
            indexByName = {
              Time = 0;
              health = 1;
              unit = 2;
              active_state = 3;
              sub_state = 4;
              result = 5;
              last_exit_status = 6;
              description = 7;
            };
            renameByName = {
              active_state = "active";
              sub_state = "sub";
              last_exit_status = "exit";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{host="psi", log_type="systemd_status"}'';
        }
      ];
    }
  ];
}
