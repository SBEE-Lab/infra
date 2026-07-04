# SjangLab Apps dashboard
# User-facing application smoke status and access side-effects.
{ datasources }:
let
  inherit (datasources) prometheus loki;
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
  version = 1;
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
      title = "Endpoint status";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 9;
        w = 24;
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
      id = 3;
      title = "Forward-auth denials by app";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 17;
      };
      fieldConfig.defaults.min = 0;
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''sum by (app) (count_over_time({log_type="authentik", event="forward_auth_deny"} | json | app != "" [$__auto]))'';
          legendFormat = "{{app}}";
        }
      ];
    }
    {
      id = 4;
      title = "App authorizations by app";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 17;
      };
      fieldConfig.defaults.min = 0;
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''sum by (app) (count_over_time({log_type="authentik", event="app_authorize"} | json | app != "" [$__auto]))'';
          legendFormat = "{{app}}";
        }
      ];
    }
    {
      id = 5;
      title = "Synthetic probes";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 25;
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
  ];
}
