# SjangLab Access & Audit drilldown dashboard
{ datasources }:
let
  inherit (datasources) loki;

  accessAuditSelector = ''{log_type="access_audit", event="ssh_login", host=~"$host", path=~"$path", ingress_network=~"$ingress_network", source_kind=~"$source_kind"}'';

  labelVar =
    name:
    let
      query = ''label_values({log_type="access_audit", event="ssh_login"}, ${name})'';
    in
    {
      inherit name query;
      label = name;
      type = "query";
      datasource = loki;
      definition = query;
      refresh = 1;
      sort = 1;
      multi = true;
      includeAll = true;
      allValue = ".*";
      current = {
        selected = true;
        text = "All";
        value = "$__all";
      };
      options = [ ];
    };

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
  templating.list = [
    (labelVar "host")
    (labelVar "path")
    (labelVar "ingress_network")
    (labelVar "source_kind")
  ];
  annotations.list = [ ];
  panels = [
    (row {
      id = 1;
      title = "SSH access audit";
      y = 0;
    })
    {
      id = 2;
      title = "SSH logins by path";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 1;
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
          expr = "sum by (path) (count_over_time(${accessAuditSelector}[$__auto]))";
          legendFormat = "{{path}}";
        }
      ];
    }
    {
      id = 3;
      title = "SSH logins by target host";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 1;
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
          expr = "sum by (host) (count_over_time(${accessAuditSelector}[$__auto]))";
          legendFormat = "{{host}}";
        }
      ];
    }
    {
      id = 4;
      title = "Current access mix";
      type = "table";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 8;
        x = 0;
        y = 9;
      };
      options = {
        showHeader = true;
        cellHeight = "sm";
        footer.show = false;
        sortBy = [
          {
            displayName = "count";
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
              path = 0;
              ingress_network = 1;
              source_kind = 2;
              Value = 3;
            };
            renameByName = {
              ingress_network = "ingress network";
              source_kind = "source kind";
              Value = "count";
            };
          };
        }
      ];
      targets = [
        {
          refId = "A";
          datasource = loki;
          expr = "sum by (path, ingress_network, source_kind) (count_over_time(${accessAuditSelector}[$__range]))";
          queryType = "instant";
          instant = true;
        }
      ];
    }
    (jsonTable {
      id = 5;
      title = "Unknown or unmatched SSH access";
      gridPos = {
        h = 8;
        w = 16;
        x = 8;
        y = 9;
      };
      expr = ''{log_type="access_audit", event="ssh_login", host=~"$host", path=~"unknown|bastion", ingress_network=~"$ingress_network", source_kind=~"$source_kind"} | json | correlation_status != "matched"'';
      exclude = {
        bastion_child_pid = true;
        bastion_local_ip = true;
        bastion_local_port = true;
        bastion_pid = true;
        bastion_source_port = true;
        bastion_target_ip = true;
        bastion_target_port = true;
        emitter_host = true;
        event = true;
        external_source_port = true;
        host = true;
        log_type = true;
        message = true;
        source_host = true;
        target_ip = true;
        target_network = true;
        target_port = true;
      };
      index = {
        Time = 0;
        target_host = 1;
        ssh_user = 2;
        source_ip = 3;
        path = 4;
        ingress_network = 5;
        source_kind = 6;
        correlation_status = 7;
        correlation_delta_seconds = 8;
        key_fingerprint = 9;
      };
      rename = {
        target_host = "target host";
        ssh_user = "ssh user";
        source_ip = "source IP";
        ingress_network = "ingress network";
        source_kind = "source kind";
        correlation_status = "correlation";
        correlation_delta_seconds = "delta seconds";
        key_fingerprint = "key fingerprint";
      };
    })
    (jsonTable {
      id = 6;
      title = "Recent SSH logins";
      gridPos = {
        h = 12;
        w = 24;
        x = 0;
        y = 17;
      };
      expr = accessAuditSelector;
      exclude = {
        auth_method = true;
        bastion_child_pid = true;
        bastion_local_ip = true;
        bastion_local_port = true;
        bastion_pid = true;
        bastion_source_port = true;
        bastion_target_ip = true;
        bastion_target_port = true;
        emitter_host = true;
        event = true;
        external_source_port = true;
        host = true;
        log_type = true;
        message = true;
        source_port = true;
        target_ip = true;
        target_network = true;
        target_port = true;
      };
      index = {
        Time = 0;
        target_host = 1;
        ssh_user = 2;
        path = 3;
        ingress_network = 4;
        source_kind = 5;
        source_owner = 6;
        source_device = 7;
        source_host = 8;
        source_ip = 9;
        external_source_ip = 10;
        bastion_user = 11;
        key_type = 12;
        key_fingerprint = 13;
        correlation_status = 14;
        correlation_delta_seconds = 15;
      };
      rename = {
        target_host = "target host";
        ssh_user = "ssh user";
        ingress_network = "ingress network";
        source_kind = "source kind";
        source_owner = "source owner";
        source_device = "source device";
        source_host = "source host";
        source_ip = "source IP";
        external_source_ip = "external IP";
        bastion_user = "bastion user";
        key_type = "key type";
        key_fingerprint = "key fingerprint";
        correlation_status = "correlation";
        correlation_delta_seconds = "delta seconds";
      };
    })
    (jsonTable {
      id = 7;
      title = "Bastion correlations";
      gridPos = {
        h = 10;
        w = 24;
        x = 0;
        y = 29;
      };
      expr = ''{log_type="access_audit", event="ssh_login", path="bastion", host=~"$host", ingress_network=~"$ingress_network", source_kind=~"$source_kind"}'';
      exclude = {
        auth_method = true;
        bastion_child_pid = true;
        bastion_local_ip = true;
        bastion_local_port = true;
        bastion_pid = true;
        bastion_source_port = true;
        bastion_target_ip = true;
        bastion_target_port = true;
        emitter_host = true;
        event = true;
        external_source_port = true;
        host = true;
        log_type = true;
        message = true;
        path = true;
        source_host = true;
        source_ip = true;
        source_port = true;
        target_ip = true;
        target_network = true;
        target_port = true;
      };
      index = {
        Time = 0;
        external_source_ip = 1;
        source_owner = 2;
        source_device = 3;
        bastion_user = 4;
        bastion_ssh_user = 5;
        target_host = 6;
        ssh_user = 7;
        key_fingerprint = 8;
        bastion_key_fingerprint = 9;
        correlation_status = 10;
        correlation_delta_seconds = 11;
      };
      rename = {
        external_source_ip = "external IP";
        source_owner = "source owner";
        source_device = "source device";
        bastion_user = "bastion user";
        bastion_ssh_user = "bastion ssh user";
        target_host = "target host";
        ssh_user = "ssh user";
        key_fingerprint = "target key";
        bastion_key_fingerprint = "bastion key";
        correlation_status = "correlation";
        correlation_delta_seconds = "delta seconds";
      };
    })
    (row {
      id = 8;
      title = "Raw SSH evidence";
      y = 39;
    })
    {
      id = 9;
      title = "Raw SSH events drilldown";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 10;
        w = 12;
        x = 0;
        y = 40;
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
          expr = ''{log_type="ssh", host=~"$host"} | json | line_format "{{.event}} {{.user}} {{.source_ip}}:{{.source_port}} {{.message}}"'';
        }
      ];
    }
    (jsonTable {
      id = 10;
      title = "Raw bastion forwards drilldown";
      gridPos = {
        h = 10;
        w = 12;
        x = 12;
        y = 40;
      };
      expr = ''{log_type="ssh_bastion", event="bastion_forward"}'';
      exclude = {
        auth_method = true;
        bastion_child_pid = true;
        bastion_local_ip = true;
        bastion_pid = true;
        event = true;
        host = true;
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
        key_type = 7;
        key_fingerprint = 8;
        message = 9;
      };
      rename = {
        source_ip = "source IP";
        source_port = "source port";
        bastion_user = "user";
        target_host = "target";
        target_ip = "target IP";
        bastion_local_port = "eta port";
        key_type = "key type";
        key_fingerprint = "key fingerprint";
        message = "summary";
      };
    })
    (row {
      id = 11;
      title = "Authentik";
      y = 50;
    })
    {
      id = 12;
      title = "Logins over time";
      type = "timeseries";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 51;
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
      id = 13;
      title = "Failed logins";
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 51;
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
      id = 14;
      title = "App authorizations";
      gridPos = {
        h = 8;
        w = 12;
        x = 0;
        y = 59;
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
      id = 15;
      title = "Admin changes & policy errors";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 8;
        w = 12;
        x = 12;
        y = 59;
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
      id = 16;
      title = "Headscale";
      y = 67;
    })
    (jsonTable {
      id = 17;
      title = "Node inventory (latest snapshots)";
      gridPos = {
        h = 8;
        w = 24;
        x = 0;
        y = 68;
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
      id = 18;
      title = "Control-plane events";
      type = "logs";
      datasource = loki;
      gridPos = {
        h = 9;
        w = 24;
        x = 0;
        y = 76;
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
