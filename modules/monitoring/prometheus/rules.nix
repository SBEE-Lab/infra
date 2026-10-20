{ config, lib, ... }:
let
  monitoredHosts = lib.attrNames (
    lib.filterAttrs (_: host: host.wg-admin != null) config.networking.sbee.hosts
  );
  targets = import ../targets.nix;
  backupHosts = [
    "psi"
    "rho"
    "tau"
  ];
  runbook = "https://github.com/SBEE-Lab/infra/blob/main/docs/admin/monitoring.md#prometheus-rho";
  hostAlertAnnotations = {
    runbook_url = runbook;
    dashboard_url = "https://logging.sjanglab.org/d/sjanglab-hosts/sjanglab-hosts";
  };
  postgresqlAlertAnnotations = {
    runbook_url = runbook;
    dashboard_url = "https://logging.sjanglab.org/d/sjanglab-postgresql/sjanglab-postgresql";
  };
  opsWarning = {
    severity = "warning";
    response = "business-hours";
    signal = "host-metrics";
  };
  opsCritical = opsWarning // {
    severity = "critical";
    response = "immediate";
  };
  alertingTargets = lib.filterAttrs (_: target: target.response != "observe") targets;
  observationRules = lib.mapAttrsToList (service: target: {
    alert = "ServiceObservationMissing";
    expr = ''absent_over_time(probe_success{service="${service}",job=~"blackbox_.*"}[5m])'';
    for = "5m";
    labels = {
      inherit service;
      inherit (target) host;
      severity = "warning";
      response = "business-hours";
      signal = "probe";
    };
    annotations = {
      summary = "Service check results are missing";
      description = "${service}: restore the probe and scrape path. Missing results do not establish service failure or recovery.";
      runbook_url = runbook;
    };
  }) alertingTargets;
  serviceRules = lib.mapAttrsToList (service: target: {
    alert = "ServiceUnavailable";
    expr = ''probe_success{service="${service}",job=~"blackbox_.*"} == 0'';
    for = target.failureFor;
    labels = {
      inherit service;
      inherit (target) host response;
      severity = if target.response == "immediate" then "critical" else "warning";
      signal = "probe";
    };
    annotations = {
      summary = "Service access check failed";
      description = "${service}: ${target.access} access check failed; inspect probe details and application logs. This is not a full functional test.";
      runbook_url = runbook;
    };
  }) alertingTargets;
in
{
  imports = [ ./storage-rules.nix ];

  services.prometheus.rules = [
    (builtins.toJSON {
      groups = [
        {
          name = "system_alerts";
          interval = "60s";
          rules =
            (map (host: {
              alert = "HostMetricsMissing";
              expr = ''absent_over_time(host_memory_total_bytes{host="${host}"}[5m])'';
              for = "5m";
              labels = {
                inherit host;
                severity = "warning";
                response = "business-hours";
                signal = "collection";
              };
              annotations = hostAlertAnnotations // {
                summary = "Host observation unavailable";
                description = "${host}: host metrics have not arrived for 5 minutes. Service health is unknown, not confirmed down; inspect Vector and the collection path.";
              };
            }) monitoredHosts)
            ++ serviceRules
            ++ observationRules
            ++ (lib.concatMap (
              host:
              map
                (unit: {
                  alert = "BackupObservationMissing";
                  expr = ''absent_over_time(infra_job_last_completion_timestamp_seconds{host="${host}",unit="${unit}",scheduled="true"}[10m])'';
                  for = "15m";
                  labels = opsWarning // {
                    inherit host unit;
                    signal = "collection";
                  };
                  annotations = {
                    summary = "Backup completion observations are missing";
                    description = "${host} ${unit}: restore collection or complete the initial verification. Missing observations do not establish failure or success.";
                    runbook_url = runbook;
                  };
                })
                [
                  "borgbackup-job-local.service"
                  "borgbackup-verify-local.service"
                ]
            ) backupHosts)
            ++ [
              {
                alert = "DiskSpaceLow";
                expr = ''
                  (
                    host_filesystem_free_bytes{mountpoint=~"/|/srv|/data"} /
                    host_filesystem_total_bytes{mountpoint=~"/|/srv|/data"}
                  ) < 0.10
                  and
                  host_filesystem_free_bytes{mountpoint=~"/|/srv|/data"} < 107374182400
                '';
                for = "30m";
                labels = opsWarning;
                annotations = hostAlertAnnotations // {
                  summary = "Filesystem needs capacity";
                  description = "{{ $labels.host }}: {{ $labels.mountpoint }} has less than 10% and 100 GiB free; inspect growth and reclaim space.";
                };
              }
              {
                alert = "DiskSpaceCritical";
                expr = ''host_filesystem_free_bytes{mountpoint=~"/|/srv|/data"} < 10737418240'';
                for = "5m";
                labels = opsCritical;
                annotations = hostAlertAnnotations // {
                  summary = "Filesystem nearly exhausted";
                  description = "{{ $labels.host }}: {{ $labels.mountpoint }} has less than 10 GiB free; reclaim capacity before writes fail.";
                };
              }

              {
                alert = "PostgresqlExporterMissing";
                expr = ''absent_over_time(pg_up{host="rho"}[5m])'';
                for = "5m";
                labels = opsWarning // {
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
                for = "5m";
                labels = opsWarning // {
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
                expr = ''pg_up{host="rho"} == 0'';
                for = "5m";
                labels = opsCritical // {
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL is down";
                  description = "{{ $labels.host }}: exporter cannot query PostgreSQL";
                };
              }

              {
                alert = "PostgresqlDown";
                expr = ''pg_up{host="tau"} == 0'';
                for = "10m";
                labels = opsWarning // {
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replica cannot be queried";
                  description = "tau: inspect the replica and exporter; primary availability is checked separately.";
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
                for = "10m";
                labels = opsWarning // {
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
                  host = "rho";
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
                labels = opsWarning // {
                  severity = "critical";
                  host = "rho";
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
                labels = opsWarning // {
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
                labels = opsWarning // {
                  severity = "critical";
                  host = "rho";
                  service = "postgresql";
                };
                annotations = postgresqlAlertAnnotations // {
                  summary = "PostgreSQL replication slot needs repair";
                  description = "rho slot tau WAL status is {{ $labels.wal_status }}";
                };
              }

              {
                alert = "BlackboxExporterDown";
                expr = ''up{job="blackbox_exporter"} == 0'';
                for = "5m";
                labels = {
                  host = "eta";
                  severity = "warning";
                  response = "business-hours";
                  signal = "collection";
                };
                annotations = {
                  summary = "Service observation unavailable";
                  description = "eta blackbox exporter is unavailable; service checks are unknown. Restore the probe before interpreting application failures.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "TlsCertificateExpiringSoon";
                expr = ''(probe_ssl_earliest_cert_expiry{job=~"blackbox_.*",response!="observe"} - time()) / 86400 < 7'';
                for = "30m";
                labels = {
                  severity = "warning";
                  response = "business-hours";
                  signal = "probe";
                };
                annotations = {
                  summary = "TLS certificate renewal needs attention";
                  description = "{{ $labels.service }} certificate expires in {{ $value | humanize }} days; inspect renewal before access is affected.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "PrometheusRuleEvaluationFailed";
                expr = "increase(prometheus_rule_evaluation_failures_total[5m]) > 0";
                for = "5m";
                labels = {
                  host = "rho";
                  severity = "warning";
                  response = "business-hours";
                  signal = "collection";
                };
                annotations = {
                  summary = "Alert evaluation is failing";
                  description = "Inspect Prometheus logs and repair rule evaluation; some failures may not be detected.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "VectorDeliveryErrors";
                expr = ''
                  sum by (host) (
                    increase(vector_component_errors_total{component_kind="sink"}[10m])
                  ) > 0
                '';
                for = "5m";
                labels = {
                  severity = "warning";
                  response = "business-hours";
                  signal = "collection";
                };
                annotations = {
                  summary = "Telemetry delivery is failing";
                  description = "{{ $labels.host }}: inspect Vector sink errors and the ingest path; service health is not established by delivery failure.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "ScheduledJobFailed";
                expr = ''infra_job_last_result{scheduled="true"} > 0'';
                for = "15m";
                labels = opsWarning;
                annotations = {
                  summary = "Scheduled job needs attention";
                  description = "{{ $labels.host }} {{ $labels.unit }}: the last completed attempt did not succeed cleanly. Inspect its journal for the exit status and details before retrying.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "BackupDumpFailed";
                expr = ''infra_job_last_result{host=~"psi|rho|tau",unit="postgresqlBackup.service"} > 0'';
                for = "15m";
                labels = opsWarning // {
                  signal = "job";
                };
                annotations = {
                  summary = "Backup preparation failed";
                  description = "{{ $labels.host }}: the PostgreSQL dump did not finish cleanly. Inspect postgresqlBackup.service; its failure can prevent Borg from starting.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "BackupCompletionOverdue";
                expr = ''
                  (time() - infra_job_last_completion_timestamp_seconds{
                    host=~"psi|rho|tau",unit="borgbackup-job-local.service",scheduled="true"
                  } > 129600)
                  and on (host, unit)
                  (infra_job_last_result{scheduled="true"} == 0)
                '';
                for = "15m";
                labels = opsWarning // {
                  signal = "job";
                };
                annotations = {
                  summary = "Daily backup completion is overdue";
                  description = "{{ $labels.host }}: no new completion for more than 36 hours after the last clean attempt. Inspect the timer, PostgreSQL dependency, and Borg journal. Failed attempts are covered by ScheduledJobFailed.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "BackupVerificationOverdue";
                expr = ''
                  (time() - infra_job_last_completion_timestamp_seconds{
                    host=~"psi|rho|tau",unit="borgbackup-verify-local.service",scheduled="true"
                  } > 777600)
                  and on (host, unit)
                  (infra_job_last_result{scheduled="true"} == 0)
                '';
                for = "15m";
                labels = opsWarning // {
                  signal = "job";
                };
                annotations = {
                  summary = "Weekly backup verification is overdue";
                  description = "{{ $labels.host }}: no new verification completion for more than 9 days after the last clean attempt. Inspect its timer and journal. Failed attempts are covered by ScheduledJobFailed.";
                  runbook_url = runbook;
                };
              }
              {
                alert = "Watchdog";
                expr = "vector(1)";
                labels = {
                  severity = "none";
                };
                annotations = {
                  summary = "Alerting watchdog";
                  description = "Checks evaluation and Alertmanager delivery through the external dead-man switch.";
                };
              }
            ];
        }
      ];
    })
  ];
}
