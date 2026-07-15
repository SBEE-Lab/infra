# PostgreSQL health metrics and bounded replication audit snapshots.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.networking.hostName;
  isPrimary = host == "rho";
  configuredRole = if isPrimary then "primary" else "replica";
  systemCollector = config.networking.sbee.hosts.rho.wg-admin;
  auditQuery =
    if isPrimary then
      ''
        SELECT json_build_object(
          'host', '${host}',
          'log_type', 'postgresql_audit',
          'event', 'replication_snapshot',
          'configured_role', '${configuredRole}',
          'observed_role', CASE WHEN pg_is_in_recovery() THEN 'replica' ELSE 'primary' END,
          'healthy', NOT pg_is_in_recovery()
            AND EXISTS (
              SELECT 1 FROM pg_stat_replication
              WHERE application_name = 'tau' AND state = 'streaming'
            ),
          'sender_state', COALESCE((
            SELECT state FROM pg_stat_replication
            WHERE application_name = 'tau' LIMIT 1
          ), 'missing'),
          'sync_state', COALESCE((
            SELECT sync_state FROM pg_stat_replication
            WHERE application_name = 'tau' LIMIT 1
          ), 'missing'),
          'byte_lag', COALESCE((
            SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)::bigint
            FROM pg_stat_replication
            WHERE application_name = 'tau' LIMIT 1
          ), 0),
          'slot_active', COALESCE((
            SELECT active FROM pg_replication_slots WHERE slot_name = 'tau'
          ), false),
          'slot_wal_status', COALESCE((
            SELECT wal_status FROM pg_replication_slots WHERE slot_name = 'tau'
          ), 'missing'),
          'slot_safe_wal_size_bytes', (
            SELECT safe_wal_size FROM pg_replication_slots WHERE slot_name = 'tau'
          ),
          'current_lsn', pg_current_wal_lsn()::text
        )::text;
      ''
    else
      ''
        SELECT json_build_object(
          'host', '${host}',
          'log_type', 'postgresql_audit',
          'event', 'replication_snapshot',
          'configured_role', '${configuredRole}',
          'observed_role', CASE WHEN pg_is_in_recovery() THEN 'replica' ELSE 'primary' END,
          'healthy', pg_is_in_recovery()
            AND EXISTS (SELECT 1 FROM pg_stat_wal_receiver WHERE status = 'streaming'),
          'receiver_state', COALESCE((
            SELECT status FROM pg_stat_wal_receiver LIMIT 1
          ), 'missing'),
          'receive_lsn', COALESCE(pg_last_wal_receive_lsn()::text, '0/0'),
          'replay_lsn', COALESCE(pg_last_wal_replay_lsn()::text, '0/0'),
          'replay_lag_bytes', COALESCE(
            pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())::bigint,
            0
          ),
          'last_message_age_seconds', COALESCE((
            SELECT EXTRACT(EPOCH FROM now() - last_msg_receipt_time)::bigint
            FROM pg_stat_wal_receiver LIMIT 1
          ), -1)
        )::text;
      '';
  auditScript = pkgs.writeShellScript "postgresql-replication-audit" ''
    set -u
    if snapshot=$(
      ${lib.getExe' config.services.postgresql.package "psql"} \
        --no-psqlrc \
        --tuples-only \
        --no-align \
        --dbname postgres \
        --command ${lib.escapeShellArg auditQuery} \
        2>/dev/null
    ); then
      printf '%s\n' "$snapshot"
    else
      ${lib.getExe pkgs.jq} -nc \
        --arg host ${lib.escapeShellArg host} \
        --arg configured_role ${lib.escapeShellArg configuredRole} \
        '{
          host: $host,
          log_type: "postgresql_audit",
          event: "replication_snapshot",
          configured_role: $configured_role,
          observed_role: "unavailable",
          healthy: false,
          error: "database_query_failed"
        }'
      exit 1
    fi
  '';
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = if isPrimary then "PostgreSQL primary rho" else "PostgreSQL replica tau";
      group = "platform";
      systemdService = "postgresql.service";
      interval = 60;
    }
  ];

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "127.0.0.1";
    runAsLocalSuperUser = true;
    extraFlags = [
      "--collector.stat_wal_receiver"
      # postgres_exporter 0.20 queries nonexistent pg_stat_replication.slot_name,
      # which floods PostgreSQL logs and prevents this collector from emitting data.
      "--no-collector.stat_replication"
    ];
  };

  systemd.services.postgresql-replication-audit = {
    description = "Record PostgreSQL replication audit snapshot";
    after = [ "postgresql.service" ];
    path = [ config.services.postgresql.package ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      ExecStart = auditScript;
    };
  };

  systemd.timers.postgresql-replication-audit = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
      RandomizedDelaySec = "10s";
      Persistent = true;
    };
  };

  services.vector.settings = {
    sources = {
      postgresql_metrics = {
        type = "prometheus_scrape";
        endpoints = [ "http://127.0.0.1:9187/metrics" ];
        scrape_interval_secs = 30;
      };
      postgresql_audit_journal = {
        type = "journald";
        include_units = [
          "postgresql-replication-audit.service"
          "postgresql-replica-init.service"
        ];
      };
    };

    transforms = {
      tag_postgresql_metrics = {
        type = "remap";
        inputs = [ "postgresql_metrics" ];
        source = ''.tags.host = "${host}"'';
      };
      parse_postgresql_audit = {
        type = "remap";
        inputs = [ "postgresql_audit_journal" ];
        source = ''
          parsed = parse_json(to_string(.message) ?? "{}") ?? {}
          . = merge!(., parsed)
        '';
      };
      filter_postgresql_audit = {
        type = "filter";
        inputs = [ "parse_postgresql_audit" ];
        condition = ''.log_type == "postgresql_audit"'';
      };
    };

    sinks = {
      postgresql_metrics_remote = lib.mkIf (!isPrimary) {
        type = "prometheus_remote_write";
        inputs = [ "tag_postgresql_metrics" ];
        endpoint = "http://${systemCollector}:9090/api/v1/write";
        batch.timeout_secs = 10;
        healthcheck.enabled = false;
      };
      postgresql_metrics_local = lib.mkIf isPrimary {
        type = "prometheus_exporter";
        inputs = [ "tag_postgresql_metrics" ];
        address = "127.0.0.1:9599";
      };
      postgresql_audit_remote = lib.mkIf (!isPrimary) {
        type = "loki";
        inputs = [ "filter_postgresql_audit" ];
        endpoint = "http://${systemCollector}:3100";
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          log_type = "{{ log_type }}";
          event = "{{ event }}";
        };
        batch.timeout_secs = 10;
      };
      postgresql_audit_local = lib.mkIf isPrimary {
        type = "loki";
        inputs = [ "filter_postgresql_audit" ];
        endpoint = "http://127.0.0.1:3100";
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          log_type = "{{ log_type }}";
          event = "{{ event }}";
        };
        batch.timeout_secs = 10;
      };
    };
  };

  services.prometheus.scrapeConfigs = lib.mkIf isPrimary [
    {
      job_name = "postgresql";
      scrape_interval = "30s";
      static_configs = [ { targets = [ "127.0.0.1:9599" ]; } ];
    }
  ];
}
