# SjangLab Hosts dashboard
# Host reachability/resource drilldown; synthetic blackbox probes will extend this.
{ datasources }:
let
  inherit (datasources) prometheus loki;

  tablePanel =
    {
      id,
      title,
      gridPos,
      expr,
      transformations,
      datasource ? prometheus,
      instant ? true,
    }:
    {
      inherit
        id
        title
        datasource
        gridPos
        transformations
        ;
      type = "table";
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      targets = [
        {
          refId = "A";
          inherit datasource expr instant;
          format = "table";
        }
      ];
    };
in
{
  uid = "sjanglab-hosts";
  title = "SjangLab Hosts";
  tags = [
    "infra"
    "hosts"
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
    (tablePanel {
      id = 1;
      title = "Metrics freshness";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 0;
      };
      expr = "time() - max by (host) (timestamp(host_memory_total_bytes))";
      transformations = [
        { id = "labelsToFields"; }
        {
          id = "organize";
          options = {
            excludeByName.Time = true;
            indexByName = {
              host = 0;
              Value = 1;
            };
            renameByName.Value = "seconds since last metric";
          };
        }
      ];
    })
    (tablePanel {
      id = 2;
      title = "Prometheus targets";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 0;
      };
      expr = "up";
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
    })
    {
      id = 3;
      title = "CPU busy";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 8;
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
      id = 4;
      title = "Memory available";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 8;
        y = 8;
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
      title = "Root filesystem free";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 8;
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
      id = 6;
      title = "Network throughput";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 16;
      };
      fieldConfig.defaults.unit = "bps";
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "sum by (host) (rate(host_network_receive_bytes_total[5m])) * 8";
          legendFormat = "{{host}} rx";
        }
        {
          refId = "B";
          datasource = prometheus;
          expr = "sum by (host) (rate(host_network_transmit_bytes_total[5m])) * 8";
          legendFormat = "{{host}} tx";
        }
      ];
    }
    {
      id = 7;
      title = "Headscale node health";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 24;
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
              command = true;
              event = true;
              host = true;
              log_type = true;
              pid = true;
              source_type = true;
              stream = true;
            };
            indexByName = {
              Time = 0;
              node = 1;
              health = 2;
              health_reason = 3;
              online = 4;
              server = 5;
              user = 6;
              tags = 7;
              ip_addresses = 8;
            };
            renameByName = {
              health_reason = "reason";
              ip_addresses = "IPs";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{log_type="headscale_nodes", event="node_snapshot"}'';
        }
      ];
      timeFrom = "10m";
    }
    (tablePanel {
      id = 8;
      title = "wg-admin reachability";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 32;
      };
      expr = ''probe_success{job="blackbox_icmp"}'';
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
              service = 0;
              instance = 1;
              Value = 2;
              probe_success = 2;
            };
            renameByName = {
              service = "host";
              Value = "status";
              probe_success = "status";
            };
          };
        }
      ];
    })
  ];
}
