# PostgreSQL primary/replica health and replication audit history.
{ datasources }:
let
  inherit (datasources) prometheus loki;
  statusPanel =
    {
      id,
      title,
      x,
      expr,
    }:
    {
      inherit id title;
      type = "stat";
      datasource = prometheus;
      gridPos = {
        h = 4;
        w = 6;
        inherit x;
        y = 0;
      };
      options = {
        colorMode = "background";
        graphMode = "none";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
      };
      fieldConfig.defaults = {
        noValue = "MISSING";
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
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          inherit expr;
          instant = true;
        }
      ];
    };
in
{
  uid = "sjanglab-postgresql";
  title = "SjangLab PostgreSQL";
  tags = [
    "infra"
    "postgresql"
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
    (statusPanel {
      id = 1;
      title = "rho primary";
      x = 0;
      expr = ''pg_up{host="rho"}'';
    })
    (statusPanel {
      id = 2;
      title = "tau replica";
      x = 6;
      expr = ''pg_up{host="tau"}'';
    })
    (statusPanel {
      id = 3;
      title = "tau streaming";
      x = 12;
      expr = ''count(pg_stat_wal_receiver_flushed_lsn{host="tau", slot_name="tau", status="streaming"})'';
    })
    (statusPanel {
      id = 4;
      title = "tau slot active";
      x = 18;
      expr = ''pg_replication_slots_slot_is_active{host="rho", slot_name="tau", slot_type="physical"}'';
    })
    {
      id = 5;
      title = "Replication slot byte lag";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 4;
      };
      fieldConfig.defaults = {
        unit = "bytes";
        min = 0;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''pg_replication_slots_pg_wal_lsn_diff{host="rho", slot_name="tau"}'';
          legendFormat = "restart LSN lag";
        }
      ];
    }
    {
      id = 6;
      title = "Replication slot safe WAL";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 4;
      };
      fieldConfig.defaults = {
        unit = "bytes";
        min = 0;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''pg_replication_slots_safe_wal_size_bytes{host="rho", slot_name="tau", slot_type="physical"}'';
          legendFormat = "safe WAL";
        }
      ];
    }
    {
      id = 7;
      title = "Replica replay lag";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 12;
      };
      fieldConfig.defaults = {
        unit = "s";
        min = 0;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''pg_replication_lag_seconds{host="tau"}'';
          legendFormat = "receive to replay";
        }
        {
          refId = "B";
          datasource = prometheus;
          expr = ''pg_replication_last_replay_seconds{host="tau"}'';
          legendFormat = "last replay age";
        }
      ];
    }
    {
      id = 8;
      title = "PostgreSQL role";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 12;
      };
      fieldConfig.defaults = {
        min = 0;
        max = 1;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''pg_replication_is_replica{host=~"rho|tau"}'';
          legendFormat = "{{host}} (1=replica)";
        }
      ];
    }
    {
      id = 9;
      title = "Replication audit snapshots";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 10;
        w = 24;
        x = 0;
        y = 20;
      };
      options = {
        showTime = true;
        showLabels = false;
        wrapLogMessage = true;
        sortOrder = "Descending";
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{log_type="postgresql_audit"}'';
        }
      ];
    }
  ];
}
