# SjangLab Access & Audit drilldown dashboard
# Rows: SSH (bastion), Authentik (browser apps), Headscale (tailnet membership)
{ datasources }:
let
  inherit (datasources) loki;

  row =
    {
      id,
      title,
      y,
    }:
    {
      inherit id title;
      type = "row";
      collapsed = false;
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        inherit y;
      };
    };

  # Table built from Loki JSON log lines (extractFields pattern)
  jsonTable =
    {
      id,
      title,
      gridPos,
      expr,
      exclude ? { },
      index ? { },
      rename ? { },
      timeFrom ? null,
    }:
    let
      panel = {
        inherit id title;
        type = "table";
        datasource = loki;
        inherit gridPos;
        options = {
          showHeader = true;
          cellHeight = "sm";
          footer.show = false;
          sortBy = [
            {
              displayName = "Time";
              desc = true;
            }
          ];
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
              excludeByName = exclude;
              indexByName = index;
              renameByName = rename;
            };
          }
        ];
        targets = [
          {
            refId = "A";
            datasource = loki;
            inherit expr;
          }
        ];
      };
    in
    panel // (if timeFrom == null then { } else { inherit timeFrom; });
in
{
  uid = "sjanglab-access-audit";
  title = "SjangLab Access & Audit";
  tags = [
    "infra"
    "audit"
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
    (row {
      id = 1;
      title = "SSH";
      y = 0;
    })
    {
      id = 2;
      title = "Recent SSH events";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 10;
        w = 14;
        x = 0;
        y = 1;
      };
      options = {
        showTime = true;
        showLabels = false;
        wrapLogMessage = true;
        enableLogDetails = true;
        sortOrder = "Descending";
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{log_type="ssh"} | json | line_format "{{.message}}"'';
        }
      ];
    }
    {
      id = 3;
      title = "Failed SSH logins by source IP";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 10;
        w = 10;
        x = 14;
        y = 1;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
        sortBy = [
          {
            displayName = "failures";
            desc = true;
          }
        ];
      };
      transformations = [
        { id = "labelsToFields"; }
        {
          id = "organize";
          options = {
            excludeByName.Time = true;
            indexByName = {
              source_ip = 0;
              Value = 1;
            };
            renameByName.Value = "failures";
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''topk(10, sum by (source_ip) (count_over_time({log_type="ssh", event="login_failed"} | json | source_ip != "" [$__range])))'';
          queryType = "instant";
          instant = true;
        }
      ];
    }
    (jsonTable {
      id = 4;
      title = "SSH bastion forwards";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 11;
      };
      expr = ''{log_type="ssh_bastion", event="bastion_forward"}'';
      exclude = {
        auth_method = true;
        bastion_child_pid = true;
        bastion_local_ip = true;
        bastion_pid = true;
        event = true;
        host = true;
        key_fingerprint = true;
        key_type = true;
        log_type = true;
        target_port = true;
      };
      index = {
        Time = 0;
        source_ip = 1;
        source_port = 2;
        bastion_user = 3;
        target_host = 4;
        target_ip = 5;
        bastion_local_port = 6;
        message = 7;
      };
      rename = {
        source_ip = "source IP";
        source_port = "source port";
        bastion_user = "user";
        target_host = "target";
        target_ip = "target IP";
        bastion_local_port = "eta port";
        message = "summary";
      };
    })
    (row {
      id = 5;
      title = "Authentik";
      y = 19;
    })
    {
      id = 6;
      title = "Logins over time";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 20;
      };
      fieldConfig.defaults = {
        custom.drawStyle = "bars";
        custom.fillOpacity = 60;
        min = 0;
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''sum by (event) (count_over_time({log_type="authentik", event=~"login|login_failed"}[$__auto]))'';
          legendFormat = "{{event}}";
        }
      ];
    }
    (jsonTable {
      id = 7;
      title = "Failed logins";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 20;
      };
      expr = ''{log_type="authentik", event="login_failed"}'';
      exclude = {
        host = true;
        http_host = true;
        log_type = true;
        event = true;
        action = true;
      };
      index = {
        Time = 0;
        user = 1;
        source_ip = 2;
        message = 3;
      };
      rename = {
        source_ip = "source IP";
        message = "summary";
      };
    })
    (jsonTable {
      id = 8;
      title = "App authorizations";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 28;
      };
      expr = ''{log_type="authentik", event="app_authorize"}'';
      exclude = {
        host = true;
        http_host = true;
        log_type = true;
        event = true;
        action = true;
        message = true;
      };
      index = {
        Time = 0;
        user = 1;
        app = 2;
        source_ip = 3;
      };
      rename = {
        source_ip = "source IP";
      };
    })
    {
      id = 9;
      title = "Admin changes & policy errors";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 28;
      };
      options = {
        showTime = true;
        showLabels = false;
        wrapLogMessage = true;
        enableLogDetails = true;
        sortOrder = "Descending";
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{log_type="authentik", event=~"admin_change|policy_error|forward_auth_deny"} | json | line_format "{{.action}} {{.user}} {{.message}}"'';
        }
      ];
    }
    (row {
      id = 10;
      title = "Headscale";
      y = 36;
    })
    (jsonTable {
      id = 11;
      title = "Node inventory (latest snapshots)";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 37;
      };
      timeFrom = "10m";
      expr = ''{log_type="headscale_nodes", event="node_snapshot"}'';
      exclude = {
        event = true;
        host = true;
        log_type = true;
        node_id = true;
      };
      index = {
        Time = 0;
        node = 1;
        health = 2;
        health_reason = 3;
        online = 4;
        server = 5;
        user = 6;
        tags = 7;
        ip_addresses = 8;
        last_seen_seconds = 9;
        expiry_seconds = 10;
      };
      rename = {
        health_reason = "reason";
        ip_addresses = "IPs";
        last_seen_seconds = "last seen";
        expiry_seconds = "expiry";
      };
    })
    {
      id = 12;
      title = "Control-plane events";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 9;
        w = 24;
        x = 0;
        y = 45;
      };
      options = {
        showTime = true;
        showLabels = false;
        wrapLogMessage = true;
        enableLogDetails = true;
        sortOrder = "Descending";
      };
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = ''{log_type="headscale"} | json | line_format "{{.event}} {{.message}}"'';
        }
      ];
    }
  ];
}
