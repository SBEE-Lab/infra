# SjangLab public edge dashboard
# What reaches eta's public vhosts. Blackbox probes are excluded so traffic means people and scanners.
{ datasources }:
let
  p = import ./panels.nix { inherit datasources; };
  inherit (p) grid;

  public = ''{log_type="nginx_access", ingress_network="public"} | json | user_agent !~ "Blackbox-Exporter.*" | service =~ "$service" | source_ip =~ "$source_ip"'';

  textVar = name: {
    inherit name;
    label = name;
    type = "textbox";
    query = ".*";
    current = {
      text = ".*";
      value = ".*";
    };
  };
in
{
  uid = "sjanglab-edge";
  title = "SjangLab Public Edge";
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
    (textVar "service")
    (textVar "source_ip")
  ];
  annotations.list = [ ];
  panels = [
    (p.timeseries {
      id = 1;
      title = "Requests by service";
      ds = "loki";
      pos = grid 0 0 12 8;
      stack = true;
      targets = [
        {
          expr = "sum by (service) (count_over_time(${public} [$__auto]))";
          legend = "{{service}}";
        }
      ];
    })
    (p.timeseries {
      id = 2;
      title = "Requests by status";
      ds = "loki";
      pos = grid 12 0 12 8;
      stack = true;
      targets = [
        {
          expr = "sum by (status) (count_over_time(${public} [$__auto]))";
          legend = "{{status}}";
        }
      ];
    })
    (p.table {
      id = 3;
      title = "Top sources";
      ds = "loki";
      pos = grid 0 8 8 9;
      expr = "topk(15, sum by (source_ip) (count_over_time(${public} [$__range])))";
      rename.Value = "requests";
      sortBy = "requests";
    })
    (p.table {
      id = 4;
      title = "Top 404 paths (scanners)";
      ds = "loki";
      pos = grid 8 8 8 9;
      expr = ''topk(15, sum by (request_path) (count_over_time(${public} | status = "404" [$__range])))'';
      rename.Value = "requests";
      sortBy = "requests";
    })
    (p.table {
      id = 5;
      title = "Large request bodies (> 64 KiB)";
      description = "Exploit payloads arrive as unusually large requests; uploads to Nextcloud are expected here.";
      ds = "loki";
      pos = grid 16 8 8 9;
      expr = "sum by (service, http_method, request_path, source_ip) (count_over_time(${public} | request_length > 65536 [$__range]))";
      rename.Value = "requests";
      sortBy = "requests";
    })
    (p.timeseries {
      id = 6;
      title = "Public 5xx";
      ds = "prometheus";
      pos = grid 0 17 12 7;
      bars = true;
      targets = [
        {
          expr = "sum by (service) (increase(nginx_public_server_errors_total[10m]))";
          legend = "{{service}}";
        }
      ];
    })
    (p.timeseries {
      id = 7;
      title = "Sensitive paths served (should stay empty)";
      ds = "prometheus";
      pos = grid 12 17 12 7;
      bars = true;
      targets = [
        {
          expr = "sum by (service) (increase(nginx_public_sensitive_path_served_total[10m]))";
          legend = "{{service}}";
        }
      ];
    })
    (p.logs {
      id = 8;
      title = "Requests (filter with service and source_ip)";
      pos = grid 0 24 24 10;
      expr = public;
    })
  ];
}
