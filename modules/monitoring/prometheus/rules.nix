# monitoring/prometheus/rules.nix
{
  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [
        {
          name = "system_alerts";
          interval = "60s";
          rules = [
            {
              alert = "SSHBruteForce";
              expr = ''sum by (host) (count_over_time({log_type="ssh", event="login_failed"}[5m])) > 10'';
              for = "2m";
              labels.severity = "warning";
              annotations = {
                summary = "SSH brute force attempt";
                description = "{{ $labels.host }}: {{ $value }} failed SSH attempts in 5min";
              };
            }

            {
              alert = "DiskSpaceLow";
              expr = ''
                (
                  vector_host_filesystem_free_bytes{filesystem="/"} /
                  vector_host_filesystem_total_bytes
                ) * 100 < 10
              '';
              for = "5m";
              labels.severity = "warning";
              annotations = {
                summary = "Low disk space";
                description = "{{ $labels.host }}: {{ $value | humanize }}% free";
              };
            }

            {
              alert = "MemoryLow";
              expr = ''
                (
                  vector_host_memory_available_bytes /
                  vector_host_memory_total_bytes
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
                    rate(vector_host_cpu_seconds_total{mode="idle"}[5m])
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
              alert = "NodeDown";
              expr = ''up{job="vector"} == 0'';
              for = "2m";
              labels.severity = "critical";
              annotations = {
                summary = "Node is down";
                description = "{{ $labels.host }} is not responding";
              };
            }
          ];
        }
      ];
    })
  ];
}
