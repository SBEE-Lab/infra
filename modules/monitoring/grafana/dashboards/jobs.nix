# Completion records do not establish current execution state or backup integrity.
{ datasources }:
let
  inherit (datasources) prometheus;
  statPanel =
    {
      id,
      title,
      x,
      expr,
      color,
    }:
    {
      inherit id title;
      type = "stat";
      datasource = prometheus;
      description = "Latest recorded outcomes only. Missing records are unknown, not successful jobs.";
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
        noValue = "No completion data";
        decimals = 0;
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "gray";
              value = null;
            }
            {
              inherit color;
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
  resultMappings = [
    {
      type = "value";
      options = {
        "0" = {
          text = "Success";
          color = "green";
        };
        "1" = {
          text = "Unsuccessful";
          color = "red";
        };
      };
    }
  ];
  tablePanel =
    {
      id,
      title,
      x,
      expr,
      valueName,
      properties,
    }:
    {
      inherit id title;
      type = "table";
      datasource = prometheus;
      description = "Borg and PostgreSQL dumps with completion records only. Missing rows can mean never run or collection loss. Inspect the journal for details; this is not a running-state or restore-health view.";
      gridPos = {
        h = 12;
        w = 12;
        inherit x;
        y = 4;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
      };
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              __name__ = true;
              job = true;
              instance = true;
            };
            indexByName = {
              host = 0;
              unit = 1;
              scheduled = 2;
              Value = 3;
            };
            renameByName.Value = valueName;
          };
        }
      ];
      fieldConfig = {
        defaults.noValue = "Unknown";
        overrides = [
          {
            matcher = {
              id = "byName";
              options = valueName;
            };
            inherit properties;
          }
        ];
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          inherit expr;
          instant = true;
          format = "table";
        }
      ];
    };
in
{
  uid = "sjanglab-jobs";
  title = "SjangLab Jobs";
  description = "Latest Borg and PostgreSQL dump completions, not biodb lifecycle status. No completion data is unknown, not success. A successful completion does not prove backup freshness, integrity, or restorability.";
  tags = [
    "infra"
    "jobs"
  ];
  timezone = "browser";
  schemaVersion = 41;
  version = 2;
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
      title = "Jobs with completion data";
      x = 0;
      expr = "count(infra_job_last_result)";
      color = "blue";
    })
    (statPanel {
      id = 2;
      title = "Last result: success";
      x = 8;
      expr = "sum(infra_job_last_result == bool 0)";
      color = "green";
    })
    (statPanel {
      id = 3;
      title = "Last result: unsuccessful";
      x = 16;
      expr = "sum(infra_job_last_result > bool 0)";
      color = "red";
    })
    (tablePanel {
      id = 4;
      title = "Latest recorded outcome";
      x = 0;
      expr = "infra_job_last_result";
      valueName = "Last result";
      properties = [
        {
          id = "mappings";
          value = resultMappings;
        }
        {
          id = "custom.cellOptions";
          value.type = "color-text";
        }
      ];
    })
    (tablePanel {
      id = 6;
      title = "Last completion time";
      x = 12;
      expr = "1000 * (infra_job_last_completion_timestamp_seconds > 0)";
      valueName = "Completed at";
      properties = [
        {
          id = "unit";
          value = "dateTimeAsIso";
        }
      ];
    })
    {
      id = 5;
      title = "Latest recorded outcome over time";
      description = "Sampled last-result gauges, not a count or complete history of executions. Gaps are missing observations, not recovery.";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 16;
      };
      fieldConfig.defaults = {
        min = 0;
        max = 1;
        noValue = "Unknown";
        mappings = resultMappings;
        custom = {
          lineInterpolation = "stepAfter";
          spanNulls = false;
        };
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = "infra_job_last_result";
          legendFormat = "{{host}} {{unit}}";
        }
      ];
    }
  ];
}
