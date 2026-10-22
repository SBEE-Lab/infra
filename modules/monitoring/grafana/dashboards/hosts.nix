# SjangLab Hosts dashboard
# Host reachability, resources, storage health, and deployment state.
{ datasources }:
let
  inherit (datasources) prometheus loki;
  p = import ./panels.nix { inherit datasources; };
  inherit (p) grid;
  # Same mounts the disk alerts watch.
  dataMounts = ''mountpoint=~"/|/srv|/data"'';

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
  version = 2;
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
      title = "Data filesystems free";
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
          expr = "100 * host_filesystem_free_bytes{${dataMounts}} / host_filesystem_total_bytes{${dataMounts}}";
          legendFormat = "{{host}} {{mountpoint}}";
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
    (p.row {
      id = 9;
      title = "Storage";
      y = 40;
    })
    (p.table {
      id = 10;
      title = "SMART status (1 = passed)";
      ds = "prometheus";
      pos = grid 0 41 8 8;
      expr = "smartctl_device_smart_status";
      hide = [
        "instance"
        "job"
        "exported_instance"
      ];
    })
    (p.table {
      id = 11;
      title = "NVMe critical warning (0 = none)";
      ds = "prometheus";
      pos = grid 8 41 8 8;
      expr = "smartctl_device_critical_warning";
      hide = [
        "instance"
        "job"
        "exported_instance"
      ];
    })
    (p.table {
      id = 12;
      title = "RAID degraded disks (0 = healthy)";
      ds = "prometheus";
      pos = grid 16 41 8 8;
      expr = "node_md_degraded";
      hide = [
        "instance"
        "job"
        "exported_instance"
      ];
    })
    (p.row {
      id = 13;
      title = "Deployment";
      y = 49;
    })
    (p.table {
      id = 14;
      title = "Auto-upgrade: last run";
      description = "Each host applies nixbot's main build daily. A failed run keeps the previous system; manual pauses show as a stale completion time.";
      ds = "prometheus";
      pos = grid 0 50 12 7;
      expr = ''time() - infra_job_last_completion_timestamp_seconds{unit="auto-upgrade.service"}'';
      hide = [
        "instance"
        "job"
        "scheduled"
        "unit"
      ];
      rename.Value = "seconds since run";
    })
    (p.table {
      id = 15;
      title = "Auto-upgrade: last result (0 = success)";
      ds = "prometheus";
      pos = grid 12 50 12 7;
      expr = ''infra_job_last_result{unit="auto-upgrade.service"}'';
      hide = [
        "instance"
        "job"
        "scheduled"
        "unit"
      ];
      rename.Value = "result";
    })
  ];
}
