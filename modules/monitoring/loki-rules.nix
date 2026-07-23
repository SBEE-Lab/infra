{
  config,
  lib,
  pkgs,
  ...
}:
let
  opsCritical = {
    severity = "critical";
    alert_category = "ops";
    service = "backup-jobs";
  };

  opsWarning = opsCritical // {
    severity = "warning";
  };

  auditWarning = {
    severity = "warning";
    alert_category = "audit";
  };

  auditCritical = auditWarning // {
    severity = "critical";
  };

  mkAlert =
    {
      alert,
      expr,
      for,
      labels,
      summary,
      description,
    }:
    {
      inherit
        alert
        expr
        for
        labels
        ;
      annotations = {
        inherit summary description;
      };
    };

  rules = {
    groups = [
      {
        name = "systemd_job_alerts";
        interval = "60s";
        rules = [
          (mkAlert {
            alert = "BackupJobFailed";
            expr = ''
              sum by (host, unit, job_class) (
                count_over_time(
                  {log_type="systemd_status", event="job_snapshot"}
                  | json
                  | alert_enabled = "true"
                  | job_class = "backup"
                  | health = "FAIL"
                [10m])
              ) > 0
            '';
            for = "15m";
            labels = opsCritical;
            summary = "Backup job failed";
            description = "{{ $labels.host }} {{ $labels.unit }} has a failed systemd snapshot";
          })
          (mkAlert {
            alert = "BackupJobStale";
            expr = ''
              sum by (host, unit, job_class) (
                count_over_time(
                  {log_type="systemd_status", event="job_snapshot"}
                  | json
                  | alert_enabled = "true"
                  | job_class = "backup"
                  | health = "WARN"
                  | health_reason = "stale_success"
                [30m])
              ) > 0
            '';
            for = "30m";
            labels = opsWarning;
            summary = "Backup job stale";
            description = "{{ $labels.host }} {{ $labels.unit }} has exceeded its success freshness window";
          })
          (mkAlert {
            alert = "AuditJobFailed";
            expr = ''
              (
                sum by (host, unit, job_class) (
                  count_over_time(
                    {log_type="systemd_status", event="job_snapshot"}
                    | json
                    | alert_enabled = "true"
                    | job_class = "audit"
                    | health = "FAIL"
                  [10m])
                ) > 0
              )
              unless
              (
                sum by (host, unit, job_class) (
                  count_over_time(
                    {log_type="systemd_status", event="job_snapshot"}
                    | json
                    | alert_enabled = "true"
                    | job_class = "audit"
                    | health = "OK"
                  [2m])
                ) > 0
              )
            '';
            for = "5m";
            labels = auditCritical;
            summary = "Audit job failed";
            description = "{{ $labels.host }} {{ $labels.unit }} has a failed systemd snapshot";
          })
          (mkAlert {
            alert = "AuditJobStale";
            expr = ''
              (
                sum by (host, unit, job_class) (
                  count_over_time(
                    {log_type="systemd_status", event="job_snapshot"}
                    | json
                    | alert_enabled = "true"
                    | job_class = "audit"
                    | health = "WARN"
                    | health_reason = "stale_success"
                  [10m])
                ) > 0
              )
              unless
              (
                sum by (host, unit, job_class) (
                  count_over_time(
                    {log_type="systemd_status", event="job_snapshot"}
                    | json
                    | alert_enabled = "true"
                    | job_class = "audit"
                    | health = "OK"
                  [2m])
                ) > 0
              )
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Audit job stale";
            description = "{{ $labels.host }} {{ $labels.unit }} has exceeded its success freshness window";
          })
        ];
      }
      {
        name = "audit_log_alerts";
        interval = "60s";
        rules = [
          (mkAlert {
            alert = "AuditCorrelatorHeartbeatMissing";
            expr = ''
              absent_over_time({log_type="access_audit", event="correlator_heartbeat", correlator="ssh_access"}[5m])
            '';
            for = "2m";
            labels = auditCritical // {
              correlator = "ssh_access";
            };
            summary = "SSH access audit correlator heartbeat missing";
            description = "rho has not received a heartbeat from the SSH access audit correlator";
          })
          (mkAlert {
            alert = "AuditCorrelatorHeartbeatMissing";
            expr = ''
              absent_over_time({log_type="access_audit", event="correlator_heartbeat", correlator="tailnet_app_access"}[5m])
            '';
            for = "2m";
            labels = auditCritical // {
              correlator = "tailnet_app_access";
            };
            summary = "Tailnet app access audit correlator heartbeat missing";
            description = "rho has not received a heartbeat from the tailnet app access audit correlator";
          })
          (mkAlert {
            alert = "PostgresqlAuditSnapshotsMissing";
            expr = ''
              absent_over_time({host="rho", log_type="postgresql_audit", event="replication_snapshot"}[5m])
            '';
            for = "2m";
            labels = auditCritical // {
              host = "rho";
              service = "postgresql";
            };
            summary = "PostgreSQL audit snapshots missing";
            description = "rho has not recorded a PostgreSQL replication audit snapshot for 5 minutes";
          })
          (mkAlert {
            alert = "PostgresqlAuditSnapshotsMissing";
            expr = ''
              absent_over_time({host="tau", log_type="postgresql_audit", event="replication_snapshot"}[5m])
            '';
            for = "2m";
            labels = auditCritical // {
              host = "tau";
              service = "postgresql";
            };
            summary = "PostgreSQL audit snapshots missing";
            description = "rho has not received a tau PostgreSQL replication audit snapshot for 5 minutes";
          })
          (mkAlert {
            alert = "PostgresqlReplicaReinitialized";
            expr = ''
              sum(count_over_time({host="tau", log_type="postgresql_audit", event="replica_basebackup_completed"}[10m])) > 0
            '';
            for = "0m";
            labels = auditWarning // {
              host = "tau";
              service = "postgresql";
            };
            summary = "PostgreSQL replica reinitialized";
            description = "tau completed a new pg_basebackup from rho";
          })
          (mkAlert {
            alert = "PostgresqlReplicaInitializationFailed";
            expr = ''
              sum(count_over_time({host="tau", log_type="postgresql_audit", event="replica_initialization_failed"}[10m])) > 0
            '';
            for = "0m";
            labels = auditCritical // {
              host = "tau";
              service = "postgresql";
            };
            summary = "PostgreSQL replica initialization failed";
            description = "tau failed while configuring or rebuilding its PostgreSQL replica";
          })
          (mkAlert {
            alert = "NginxAccessLogsMissing";
            expr = ''
              absent_over_time({log_type="nginx_access"}[15m])
            '';
            for = "5m";
            labels = auditWarning;
            summary = "nginx access logs missing";
            description = "rho Loki has not received nginx access logs for 15 minutes";
          })
          (mkAlert {
            alert = "OmnigraphNonTailnetAccess";
            expr = ''
              sum by (host, service, ingress_network) (
                count_over_time({log_type="nginx_access", service="omnigraph", ingress_network!~"tailnet|wg-admin"}[5m])
              ) > 0
            '';
            for = "1m";
            labels = auditWarning // {
              service = "omnigraph";
            };
            summary = "Omnigraph non-tailnet access observed";
            description = "{{ $labels.host }} received Omnigraph access from {{ $labels.ingress_network }}";
          })
          (mkAlert {
            alert = "HeadscaleNodeSnapshotsMissing";
            expr = ''
              absent_over_time({log_type="headscale_nodes", event="node_snapshot"}[15m])
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Headscale node snapshots missing";
            description = "rho Loki has not received Headscale node snapshots for 15 minutes";
          })
          (mkAlert {
            alert = "SshLoginFailureBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="ssh", event="login_failed"}[10m])
              ) > 10
            '';
            for = "5m";
            labels = auditWarning;
            summary = "SSH login failure burst";
            description = "{{ $labels.host }} observed more than 10 SSH login failures in 10 minutes";
          })
          (mkAlert {
            alert = "AuthentikLoginFailureBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="authentik", event="login_failed"}[10m])
              ) > 10
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Authentik login failure burst";
            description = "{{ $labels.host }} observed more than 10 Authentik login failures in 10 minutes";
          })
          (mkAlert {
            alert = "AuthentikForwardAuthDenyBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="authentik", event="forward_auth_deny"}[10m])
              ) > 50
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Authentik forward-auth denial burst";
            description = "{{ $labels.host }} observed more than 50 forward-auth denials in 10 minutes";
          })
          (mkAlert {
            alert = "HeadscaleOidcDenied";
            expr = ''
              sum by (host) (
                count_over_time({log_type="headscale", event="oidc_denied"}[10m])
              ) > 0
            '';
            for = "1m";
            labels = auditWarning;
            summary = "Headscale OIDC access denied";
            description = "{{ $labels.host }} logged a Headscale OIDC denial";
          })
          (mkAlert {
            alert = "HeadscaleNodeExpired";
            expr = ''
              max by (host) (
                max_over_time(
                  {log_type="headscale_nodes", event="nodes_summary"}
                  | json
                  | unwrap expired_count
                [15m])
              ) > 0
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Headscale node expired";
            description = "{{ $labels.host }} reports one or more expired Headscale nodes";
          })
        ];
      }
    ];
  };

  rulesYaml = builtins.toJSON rules;
in
{
  services.loki.configuration.ruler = {
    enable_api = true;
    alertmanager_url = "http://127.0.0.1:9093/alertmanager";
    enable_alertmanager_v2 = true;
    rule_path = "/var/lib/loki/rules-tmp";
    storage = {
      type = "local";
      local.directory = pkgs.writeTextDir "fake/sjanglab-alerts.yaml" rulesYaml;
    };
  };

  systemd.tmpfiles.rules = lib.mkIf config.services.loki.enable [
    "d /var/lib/loki/rules-tmp 0700 loki loki - -"
  ];
}
