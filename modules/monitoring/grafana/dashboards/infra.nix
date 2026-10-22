# SjangLab Infrastructure overview dashboard (Grafana home)
# Answers "does anything need action now"; detail lives in the linked dashboards.
{ datasources }:
let
  p = import ./panels.nix { inherit datasources; };
  inherit (p) grid;
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
  version = 2;
  refresh = "30s";
  time = {
    from = "now-6h";
    to = "now";
  };
  templating.list = [ ];
  annotations.list = [ ];
  links =
    map
      (dashboard: {
        inherit (dashboard) title;
        type = "link";
        url = "/d/${dashboard.uid}";
      })
      [
        {
          title = "Security & audit";
          uid = "sjanglab-access-audit";
        }
        {
          title = "Public edge";
          uid = "sjanglab-edge";
        }
        {
          title = "Apps";
          uid = "sjanglab-apps";
        }
        {
          title = "Hosts";
          uid = "sjanglab-hosts";
        }
        {
          title = "Jobs";
          uid = "sjanglab-jobs";
        }
        {
          title = "PostgreSQL";
          uid = "sjanglab-postgresql";
        }
      ];
  panels = [
    (p.stat {
      id = 1;
      title = "Firing alerts";
      ds = "prometheus";
      pos = grid 0 0 6 4;
      expr = ''count(ALERTS{alertstate="firing", alertname!="Watchdog"}) or vector(0)'';
    })
    (p.stat {
      id = 2;
      title = "Intrusion indicators (7d)";
      description = "Unclassified SSH logins plus newly registered tailnet nodes. Open Security & audit for the events.";
      ds = "loki";
      pos = grid 6 0 6 4;
      expr = ''(sum(count_over_time({log_type="access_audit", path="unknown"}[7d])) or vector(0)) + (sum(count_over_time({log_type="headscale_nodes", event="node_added"}[7d])) or vector(0))'';
    })
    (p.stat {
      id = 3;
      title = "Immediate services down";
      description = "Blackbox checks for services routed as response=immediate.";
      ds = "prometheus";
      pos = grid 12 0 6 4;
      expr = ''count(probe_success{response="immediate", job=~"blackbox_.*"} == 0) or vector(0)'';
    })
    (p.stat {
      id = 4;
      title = "Oldest borg backup";
      description = "Time since the least recent host finished its local borg job. Missing records mean unknown, not success.";
      ds = "prometheus";
      pos = grid 18 0 6 4;
      unit = "s";
      noValue = "no data";
      thresholds = p.steps [
        [
          "green"
          null
        ]
        [
          "orange"
          93600
        ]
        [
          "red"
          172800
        ]
      ];
      expr = ''time() - min(infra_job_last_completion_timestamp_seconds{unit="borgbackup-job-local.service"})'';
    })
    (p.table {
      id = 5;
      title = "Active alerts";
      ds = "prometheus";
      pos = grid 0 4 16 8;
      expr = ''ALERTS{alertname!="Watchdog"}'';
      hide = [
        "Value"
        "instance"
        "job"
      ];
    })
    (p.stat {
      id = 6;
      title = "Gatus checks failing";
      description = "Host-side checks pushed to Gatus; Apps shows them beside the external probes.";
      ds = "prometheus";
      pos = grid 16 4 8 4;
      expr = "count(gatus_results_endpoint_success == 0) or vector(0)";
    })
    (p.stat {
      id = 7;
      title = "Prometheus targets down";
      ds = "prometheus";
      pos = grid 16 8 4 4;
      expr = "count(up == 0) or vector(0)";
    })
    (p.stat {
      id = 8;
      title = "Headscale nodes online";
      ds = "loki";
      pos = grid 20 8 4 4;
      thresholds = p.steps [
        [
          "blue"
          null
        ]
      ];
      # Summary snapshots avoid double-counting repeated per-node inventory rows.
      expr = ''last_over_time({log_type="headscale_nodes", event="nodes_summary"} | json | unwrap online_count [10m])'';
    })
  ];
}
