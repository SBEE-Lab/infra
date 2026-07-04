# SjangLab AI Resources dashboard
# GPU/AI-service view. GPU metrics come from prometheus-nvidia-gpu-exporter on psi.
{ datasources }:
let
  inherit (datasources) prometheus loki;
in
{
  uid = "sjanglab-ai-resources";
  title = "SjangLab AI Resources";
  tags = [
    "infra"
    "ai"
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
    {
      id = 1;
      title = "AI endpoint status";
      type = "table";
      datasource = prometheus;
      gridPos = {
        h = 8;
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
          expr = ''last_over_time(gatus_results_endpoint_success{name=~"Ollama|Docling|vLLM"}[5m])'';
          instant = true;
          format = "table";
        }
      ];
    }
    {
      id = 2;
      title = "psi CPU busy";
      type = "gauge";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 6;
        x = 12;
        y = 0;
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
          expr = ''(1 - avg(rate(host_cpu_seconds_total{host="psi", mode="idle"}[5m]))) * 100'';
        }
      ];
    }
    {
      id = 3;
      title = "psi memory available";
      type = "gauge";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 6;
        x = 18;
        y = 0;
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
          expr = ''100 * host_memory_available_bytes{host="psi"} / host_memory_total_bytes{host="psi"}'';
        }
      ];
    }
    {
      id = 4;
      title = "AI endpoint success over time";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 8;
      };
      fieldConfig.defaults = {
        min = 0;
        max = 1;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''avg by (name) (gatus_results_endpoint_success{name=~"Ollama|Docling|vLLM"})'';
          legendFormat = "{{name}}";
        }
      ];
    }
    {
      id = 5;
      title = "psi job status affecting AI/data";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 16;
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
              last_success_age_seconds = 4;
              next_due_seconds = 5;
              active_state = 6;
              sub_state = 7;
              result = 8;
              last_exit_status = 9;
            };
            renameByName = {
              active_state = "active";
              sub_state = "sub";
              last_exit_status = "exit";
              health_reason = "reason";
              last_success_age_seconds = "last success age";
              next_due_seconds = "next due";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{host="psi", log_type="systemd_status", event="job_snapshot"} | json | unit =~ "db-sync-.*"'';
        }
      ];
      timeFrom = "10m";
    }
    {
      id = 6;
      title = "GPU utilization";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 24;
      };
      fieldConfig.defaults = {
        unit = "percentunit";
        min = 0;
        max = 1;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''nvidia_smi_utilization_gpu_ratio{job="nvidia-gpu"}'';
          legendFormat = "{{uuid}}";
        }
      ];
    }
    {
      id = 7;
      title = "GPU memory used";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 8;
        y = 24;
      };
      fieldConfig.defaults = {
        unit = "bytes";
        min = 0;
      };
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''nvidia_smi_memory_used_bytes{job="nvidia-gpu"}'';
          legendFormat = "{{uuid}} used";
        }
        {
          refId = "B";
          datasource = prometheus;
          expr = ''nvidia_smi_memory_total_bytes{job="nvidia-gpu"}'';
          legendFormat = "{{uuid}} total";
        }
      ];
    }
    {
      id = 8;
      title = "GPU temperature / power";
      type = "timeseries";
      datasource = prometheus;
      gridPos = {
        h = 8;
        w = 8;
        x = 16;
        y = 24;
      };
      fieldConfig.defaults.min = 0;
      targets = [
        {
          refId = "A";
          datasource = prometheus;
          expr = ''nvidia_smi_temperature_gpu{job="nvidia-gpu"}'';
          legendFormat = "{{uuid}} °C";
        }
        {
          refId = "B";
          datasource = prometheus;
          expr = ''nvidia_smi_power_draw_watts{job="nvidia-gpu"}'';
          legendFormat = "{{uuid}} W";
        }
      ];
    }
  ];
}
