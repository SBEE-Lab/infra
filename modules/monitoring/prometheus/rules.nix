# monitoring/prometheus/rules.nix
{ config, lib, ... }:
let
  monitoredHosts = lib.attrNames (
    lib.filterAttrs (_: host: host.wg-admin != null) config.networking.sbee.hosts
  );
  monitoringSecretsText = builtins.readFile ../secrets.yaml;
  hasAlertmanagerSecrets = lib.all (name: lib.hasInfix "${name}:" monitoringSecretsText) [
    "alertmanager-bridge-token"
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
    annotations = hostAlertAnnotations // {
      summary = "Host metrics missing";
      description = "${host}: no host metrics received for 5 minutes";
    };
  }) monitoredHosts;

  rustfsStoreHosts = [
    "rho"
    "tau"
  ];

  grafanaDashboardURL = uid: "https://logging.sjanglab.org/d/${uid}/${uid}?orgId=1";
  monitoringRunbookURL = "https://github.com/SBEE-Lab/infra/blob/main/docs/admin/monitoring.md#prometheus-rho";

  hostAlertAnnotations = {
    dashboard_url = grafanaDashboardURL "sjanglab-hosts";
    runbook_url = monitoringRunbookURL;
  };

  appAlertAnnotations = {
    dashboard_url = grafanaDashboardURL "sjanglab-apps";
    runbook_url = monitoringRunbookURL;
  };

  aiAlertAnnotations = {
    dashboard_url = grafanaDashboardURL "sjanglab-ai-resources";
    runbook_url = monitoringRunbookURL;
  };

  postgresqlAlertAnnotations = {
    dashboard_url = grafanaDashboardURL "sjanglab-postgresql";
    runbook_url = monitoringRunbookURL;
  };

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
              annotations = hostAlertAnnotations;
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
                annotations = hostAlertAnnotations // {
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
                annotations = hostAlertAnnotations // {
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
                annotations = hostAlertAnnotations // {
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
                annotations = hostAlertAnnotations // {
                  summary = "High CPU load";
                  description = "{{ $labels.host }}: {{ $value | humanize }}% CPU usage";
                };
              }

              {
                alert = "PrometheusTargetDown";
                expr = ''up{job!~"blackbox_.*|blackbox_exporter|nvidia-gpu"} == 0'';
                for = "2m";
                labels = opsCritical;
                annotations = hostAlertAnnotations // {
                  summary = "Prometheus target down";
                  description = "{{ $labels.job }} target {{ $labels.instance }} is down";
                };
              }

              {
                alert = "GatusEndpointDown";
                expr = ''gatus_results_endpoint_success{group!="apps"} == 0'';
                for = "5m";
                labels = opsWarning;
                annotations = appAlertAnnotations // {
                  summary = "Gatus endpoint down";
                  description = "{{ $labels.group }}/{{ $labels.name }} is failing";
                };
              }

              {
                alert = "PostgresqlExporterMissing";
                expr = ''absent_over_time(pg_up{host="rho"}[5m])'';
                for = "2m";
                labels = opsCritical // {
                  host = "rho";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL exporter metrics missing";
                  description = "rho: no PostgreSQL exporter metrics received for 5 minutes";
                };
              }

              {
                alert = "PostgresqlExporterMissing";
                expr = ''absent_over_time(pg_up{host="tau"}[5m])'';
                for = "2m";
                labels = opsCritical // {
                  host = "tau";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL exporter metrics missing";
                  description = "tau: no PostgreSQL exporter metrics received for 5 minutes";
                };
              }

              {
                alert = "PostgresqlDown";
                expr = ''pg_up{host=~"rho|tau"} == 0'';
                for = "2m";
                labels = opsCritical // {
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL is down";
                  description = "{{ $labels.host }}: exporter cannot query PostgreSQL";
                };
              }

              {
                alert = "PostgresqlRoleInvalid";
                expr = ''
                  (pg_replication_is_replica{host="rho"} != 0)
                  or
                  (pg_replication_is_replica{host="tau"} != 1)
                '';
                for = "2m";
                labels = opsCritical // {
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "Unexpected PostgreSQL replication role";
                  description = "{{ $labels.host }} is running with an unexpected primary/replica role";
                };
              }

              {
                alert = "PostgresqlReplicaNotStreaming";
                expr = ''
                  absent_over_time(
                    pg_stat_wal_receiver_flushed_lsn{
                      host="tau", slot_name="tau", status="streaming"
                    }[5m]
                  )
                '';
                for = "2m";
                labels = opsCritical // {
                  host = "tau";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replica is not streaming";
                  description = "tau has not reported a streaming WAL receiver for 5 minutes";
                };
              }

              {
                alert = "PostgresqlReplicationLagHigh";
                expr = ''
                  pg_replication_slots_pg_wal_lsn_diff{
                    host="rho", slot_name="tau"
                  } > 268435456
                '';
                for = "5m";
                labels = opsWarning // {
                  host = "tau";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot lag is high";
                  description = "rho slot tau restart LSN lag is {{ $value | humanize1024 }}B";
                };
              }

              {
                alert = "PostgresqlReplicationLagHigh";
                expr = ''
                  pg_replication_slots_pg_wal_lsn_diff{
                    host="rho", slot_name="tau"
                  } > 1073741824
                '';
                for = "5m";
                labels = opsCritical // {
                  host = "tau";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot lag is critical";
                  description = "rho slot tau restart LSN lag is {{ $value | humanize1024 }}B";
                };
              }

              {
                alert = "PostgresqlReplicationSlotInactive";
                expr = ''
                  (
                    pg_replication_slots_slot_is_active{
                      host="rho", slot_name="tau", slot_type="physical"
                    } == 0
                  )
                  or
                  absent_over_time(
                    pg_replication_slots_slot_is_active{
                      host="rho", slot_name="tau", slot_type="physical"
                    }[5m]
                  )
                '';
                for = "5m";
                labels = opsCritical // {
                  host = "rho";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot is inactive";
                  description = "rho physical replication slot tau has been inactive for 5 minutes";
                };
              }

              {
                alert = "PostgresqlReplicationSlotWalRisk";
                expr = ''
                  pg_replication_slots_safe_wal_size_bytes{
                    host="rho", slot_name="tau", slot_type="physical"
                  } < 1073741824
                '';
                for = "5m";
                labels = opsWarning // {
                  host = "rho";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot WAL reserve is low";
                  description = "rho slot tau has only {{ $value | humanize1024 }}B safe WAL remaining";
                };
              }

              {
                alert = "PostgresqlReplicationSlotWalRisk";
                expr = ''
                  pg_replication_slots_wal_status{
                    host="rho", slot_name="tau", slot_type="physical",
                    wal_status=~"unreserved|lost"
                  } == 1
                '';
                for = "1m";
                labels = opsCritical // {
                  host = "rho";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot WAL is at risk";
                  description = "rho slot tau WAL status is {{ $labels.wal_status }}";
                };
              }

              {
                alert = "PostgresqlRoleChanged";
                expr = ''changes(pg_replication_is_replica{host=~"rho|tau"}[10m]) > 0'';
                for = "1m";
                labels = {
                  severity = "warning";
                  alert_category = "audit";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication role changed";
                  description = "{{ $labels.host }} changed PostgreSQL primary/replica role";
                };
              }

              {
                alert = "BlackboxExporterDown";
                expr = ''up{job="blackbox_exporter"} == 0'';
                for = "2m";
                labels = opsCritical;
                annotations = appAlertAnnotations // {
                  summary = "Blackbox exporter down";
                  description = "{{ $labels.host }} blackbox exporter is unavailable";
                };
              }

              {
                alert = "BlackboxProbeFailed";
                expr = ''probe_success{job=~"blackbox_.*", probe_scope=~"public|wg-admin"} == 0'';
                for = "3m";
                labels = opsCritical;
                annotations = appAlertAnnotations // {
                  summary = "Synthetic probe failed";
                  description = "{{ $labels.probe_scope }}/{{ $labels.service }} probe {{ $labels.instance }} is failing";
                };
              }

              {
                alert = "BlackboxProbeFailed";
                expr = ''probe_success{job=~"blackbox_.*", probe_scope="tailnet"} == 0'';
                for = "5m";
                labels = opsWarning;
                annotations = appAlertAnnotations // {
                  summary = "Tailnet synthetic probe failed";
                  description = "{{ $labels.service }} probe {{ $labels.instance }} is failing";
                };
              }

              {
                alert = "TlsCertificateExpiringSoon";
                expr = ''(probe_ssl_earliest_cert_expiry{job=~"blackbox_.*"} - time()) / 86400 < 14'';
                for = "30m";
                labels = opsWarning;
                annotations = appAlertAnnotations // {
                  summary = "TLS certificate expires soon";
                  description = "{{ $labels.service }} certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days";
                };
              }

              {
                alert = "TlsCertificateExpiringSoon";
                expr = ''(probe_ssl_earliest_cert_expiry{job=~"blackbox_.*"} - time()) / 86400 < 7'';
                for = "10m";
                labels = opsCritical;
                annotations = appAlertAnnotations // {
                  summary = "TLS certificate expires very soon";
                  description = "{{ $labels.service }} certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days";
                };
              }

              {
                alert = "NvidiaGpuExporterDown";
                expr = ''up{job="nvidia-gpu"} == 0'';
                for = "3m";
                labels = opsWarning;
                annotations = aiAlertAnnotations // {
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
              annotations = hostAlertAnnotations // {
                summary = "Alerting watchdog";
                description = "Always-firing alert used by Alertmanager to ping the dead-man switch";
              };
            };
        }
      ];
    })
  ];
}
