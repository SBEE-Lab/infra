# monitoring/prometheus/rules.nix
{ config, lib, ... }:
let
  monitoredHosts = lib.attrNames (
    lib.filterAttrs (_: host: host.wg-admin != null) config.networking.sbee.hosts
  );
  monitoringSecretsText = builtins.readFile ../secrets.yaml;
  hasAlertmanagerSecrets = lib.all (name: lib.hasInfix "${name}:" monitoringSecretsText) [
    "alertmanager-slack-infra-alerts-webhook"
    "alertmanager-slack-infra-audit-webhook"
    "alertmanager-healthchecks-ping-url"
  ];

  hostFreshnessRules = map (host: {
    alert = "HostMetricsMissing";
    expr = ''absent_over_time(host_memory_total_bytes{host="${host}"}[5m])'';
    for = "2m";
    labels = {
      severity = "critical";
      alert_category = "ops";
      inherit host;
    };
    annotations = {
      summary = "Host metrics missing";
      description = "${host}: no host metrics received for 5 minutes";
    };
  }) monitoredHosts;

  rustfsStoreHosts = [
    "rho"
    "tau"
  ];

  opsWarning = {
    severity = "warning";
    alert_category = "ops";
  };

  opsCritical = {
    severity = "critical";
    alert_category = "ops";
  };
in
{
  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [
        {
          name = "system_alerts";
          interval = "60s";
          rules =
            hostFreshnessRules
            ++ (lib.sbee.monitoring.mkFilesystemFreeSpaceAlerts {
              alertPrefix = "RustFSStore";
              hosts = rustfsStoreHosts;
              mountpoint = "/srv";
              warningFreePercent = 15;
              criticalFreePercent = 8;
              warningLabels = opsWarning;
              criticalLabels = opsCritical;
              summaryPrefix = "RustFS store";
            })
            ++ [
              {
                alert = "DiskSpaceLow";
                expr = ''
                  (
                    host_filesystem_free_bytes{mountpoint="/"} /
                    host_filesystem_total_bytes{mountpoint="/"}
                  ) * 100 < 10
                '';
                for = "5m";
                labels = opsWarning;
                annotations = {
                  summary = "Low disk space";
                  description = "{{ $labels.host }}: {{ $value | humanize }}% free on /";
                };
              }

              {
                alert = "DiskSpaceCritical";
                expr = ''
                  (
                    host_filesystem_free_bytes{mountpoint="/"} /
                    host_filesystem_total_bytes{mountpoint="/"}
                  ) * 100 < 5
                '';
                for = "5m";
                labels = opsCritical;
                annotations = {
                  summary = "Critically low disk space";
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
                labels = opsWarning;
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
                labels = opsWarning;
                annotations = {
                  summary = "High CPU load";
                  description = "{{ $labels.host }}: {{ $value | humanize }}% CPU usage";
                };
              }

              {
                alert = "PrometheusTargetDown";
                expr = ''up{job!~"blackbox_.*|blackbox_exporter|nvidia-gpu"} == 0'';
                for = "2m";
                labels = opsCritical;
                annotations = {
                  summary = "Prometheus target down";
                  description = "{{ $labels.job }} target {{ $labels.instance }} is down";
                };
              }

              {
                alert = "GatusEndpointDown";
                expr = ''gatus_results_endpoint_success{group!="apps"} == 0'';
                for = "5m";
                labels = opsWarning;
                annotations = {
                  summary = "Gatus endpoint down";
                  description = "{{ $labels.group }}/{{ $labels.name }} is failing";
                };
              }

              {
                alert = "BlackboxExporterDown";
                expr = ''up{job="blackbox_exporter"} == 0'';
                for = "2m";
                labels = opsCritical;
                annotations = {
                  summary = "Blackbox exporter down";
                  description = "{{ $labels.host }} blackbox exporter is unavailable";
                };
              }

              {
                alert = "BlackboxProbeFailed";
                expr = ''probe_success{job=~"blackbox_.*", probe_scope=~"public|wg-admin"} == 0'';
                for = "3m";
                labels = opsCritical;
                annotations = {
                  summary = "Synthetic probe failed";
                  description = "{{ $labels.probe_scope }}/{{ $labels.service }} probe {{ $labels.instance }} is failing";
                };
              }

              {
                alert = "BlackboxProbeFailed";
                expr = ''probe_success{job=~"blackbox_.*", probe_scope="tailnet"} == 0'';
                for = "5m";
                labels = opsWarning;
                annotations = {
                  summary = "Tailnet synthetic probe failed";
                  description = "{{ $labels.service }} probe {{ $labels.instance }} is failing";
                };
              }

              {
                alert = "TlsCertificateExpiringSoon";
                expr = ''(probe_ssl_earliest_cert_expiry{job=~"blackbox_.*"} - time()) / 86400 < 14'';
                for = "30m";
                labels = opsWarning;
                annotations = {
                  summary = "TLS certificate expires soon";
                  description = "{{ $labels.service }} certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days";
                };
              }

              {
                alert = "TlsCertificateExpiringSoon";
                expr = ''(probe_ssl_earliest_cert_expiry{job=~"blackbox_.*"} - time()) / 86400 < 7'';
                for = "10m";
                labels = opsCritical;
                annotations = {
                  summary = "TLS certificate expires very soon";
                  description = "{{ $labels.service }} certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days";
                };
              }

              {
                alert = "NvidiaGpuExporterDown";
                expr = ''up{job="nvidia-gpu"} == 0'';
                for = "3m";
                labels = opsWarning;
                annotations = {
                  summary = "GPU exporter down";
                  description = "{{ $labels.host }} nvidia-gpu exporter is unavailable";
                };
              }

            ]
            ++ lib.optional hasAlertmanagerSecrets {
              alert = "Watchdog";
              expr = "vector(1)";
              labels = {
                severity = "none";
                alert_category = "deadman";
              };
              annotations = {
                summary = "Alerting watchdog";
                description = "Always-firing alert used by Alertmanager to ping the dead-man switch";
              };
            };
        }
      ];
    })
  ];
}
