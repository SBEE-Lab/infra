# monitoring/prometheus/rules.nix
{ config, lib, ... }:
let
  monitoredHosts = lib.attrNames (
    lib.filterAttrs (_: host: host.wg-admin != null) config.networking.sbee.hosts
  );

  hostFreshnessRules = map (host: {
    alert = "HostMetricsMissing";
    expr = ''absent_over_time(host_memory_total_bytes{host="${host}"}[10m])'';
    for = "2m";
    labels = {
      severity = "critical";
      inherit host;
    };
    annotations = {
      summary = "Host metrics missing";
      description = "${host}: no host metrics received for 10 minutes";
    };
  }) monitoredHosts;
in
{
  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [
        {
          name = "system_alerts";
          interval = "60s";
          rules = hostFreshnessRules ++ [
            {
              alert = "DiskSpaceLow";
              expr = ''
                (
                  host_filesystem_free_bytes{mountpoint="/"} /
                  host_filesystem_total_bytes{mountpoint="/"}
                ) * 100 < 10
              '';
              for = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "Low disk space";
                description = "{{ $labels.host }}: {{ $value | humanize }}% free on /";
              };
            }

            {
              alert = "MemoryLow";
              expr = ''
                (
                  host_memory_available_bytes /
                  host_memory_total_bytes
                ) * 100 < 10
              '';
              for = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "Low memory";
                description = "{{ $labels.host }}: {{ $value | humanize }}% available";
              };
            }

            {
              alert = "HighCPULoad";
              expr = ''
                (
                  1 - avg by (host) (
                    rate(host_cpu_seconds_total{mode="idle"}[5m])
                  )
                ) * 100 > 90
              '';
              for = "10m";
              labels.severity = "warning";
              annotations = {
                summary = "High CPU load";
                description = "{{ $labels.host }}: {{ $value | humanize }}% CPU usage";
              };
            }

            {
              alert = "PrometheusTargetDown";
              expr = "up == 0";
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Prometheus target down";
                description = "{{ $labels.job }} target {{ $labels.instance }} is down";
              };
            }

            {
              alert = "GatusEndpointDown";
              expr = "gatus_results_endpoint_success == 0";
              for = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "Gatus endpoint down";
                description = "{{ $labels.group }}/{{ $labels.name }} is failing";
              };
            }

            {
              alert = "BlackboxProbeFailed";
              expr = ''probe_success{job=~"blackbox_.*"} == 0'';
              for = "3m";
              labels.severity = "warning";
              annotations = {
                summary = "Synthetic probe failed";
                description = "{{ $labels.probe_scope }}/{{ $labels.service }} probe {{ $labels.instance }} is failing";
              };
            }
          ];
        }
      ];
    })
  ];
}
