# SjangLab Jobs dashboard
# Batch/sync health. Current source is psi biodb systemd status snapshots in Loki.
{ datasources }:
let
  inherit (datasources) loki;

  statPanel =
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
  uid = "sjanglab-jobs";
  title = "SjangLab Jobs";
  tags = [
    "infra"
    "jobs"
  ];
  timezone = "browser";
  schemaVersion = 41;
  version = 1;
  refresh = "1m";
  time = {
    from = "now-24h";
    to = "now";
  };
  templating.list = [ ];
  annotations.list = [ ];
  panels = [
    (statPanel {
      id = 1;
      title = "psi job failures";
      x = 0;
      expr = ''sum(count_over_time({host="psi", log_type="systemd_status", event="job_snapshot"} | json | health = "FAIL" [10m]))'';
    })
    (statPanel {
      id = 2;
      title = "biodb failures";
      x = 8;
      expr = ''sum(count_over_time({host="psi", log_type="systemd_status", event="job_snapshot"} | json | health = "FAIL" | unit =~ "biodb-.*" [10m]))'';
    })
    (statPanel {
      id = 3;
      title = "backup failures";
      x = 16;
      expr = ''sum(count_over_time({log_type="systemd_status", event="job_snapshot"} | json | health = "FAIL" | unit =~ ".*backup.*|.*restic.*|.*rustic.*|.*minio.*" [10m]))'';
    })
    {
      id = 4;
      title = "Latest psi job status";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 12;
        w = 24;
        x = 0;
        y = 4;
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
              health_reason = 2;
              unit = 3;
              active_state = 4;
              sub_state = 5;
              result = 6;
              last_exit_status = 7;
              last_success_age_seconds = 8;
              next_due_seconds = 9;
              max_success_age_seconds = 10;
              description = 11;
            };
            renameByName = {
              active_state = "active";
              sub_state = "sub";
              last_exit_status = "exit";
              health_reason = "reason";
              last_success_age_seconds = "last success age";
              next_due_seconds = "next due";
              max_success_age_seconds = "max success age";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{host="psi", log_type="systemd_status", event="job_snapshot"}'';
        }
      ];
      timeFrom = "10m";
    }
    {
      id = 5;
      title = "Job failures over time";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 16;
      };
      fieldConfig.defaults.min = 0;
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''sum(count_over_time({host="psi", log_type="systemd_status", event="job_snapshot"} | json | health = "FAIL" [$__auto]))'';
          legendFormat = "failures";
        }
      ];
    }
  ];
}
