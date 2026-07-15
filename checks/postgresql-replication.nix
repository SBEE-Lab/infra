{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      eta = self.nixosConfigurations.eta.config;
      rho = self.nixosConfigurations.rho.config;
      tau = self.nixosConfigurations.tau.config;
      state = pkgs.writeText "postgresql-replication-state.json" (
        builtins.toJSON {
          targetRequires = tau.systemd.targets.postgresql.requires;
          rhoExporter = rho.services.prometheus.exporters.postgres.enable;
          tauExporter = tau.services.prometheus.exporters.postgres.enable;
          rhoExporterFlags = rho.services.prometheus.exporters.postgres.extraFlags;
          tauExporterFlags = tau.services.prometheus.exporters.postgres.extraFlags;
          rhoGatusChecks = map (check: check.name) rho.gatusCheck.push;
          tauGatusChecks = map (check: check.name) tau.gatusCheck.push;
          etaGatusEndpoints = map (endpoint: endpoint.name) eta.services.gatus.settings.external-endpoints;
          tauAuditTimer = tau.systemd.timers.postgresql-replication-audit.wantedBy or [ ];
          tauMetricSource = tau.services.vector.settings.sources.postgresql_metrics.type or null;
          rhoMetricSource = rho.services.vector.settings.sources.postgresql_metrics.type or null;
          metricTransform = rho.services.vector.settings.transforms.tag_postgresql_metrics.source or "";
          auditTransform = rho.services.vector.settings.transforms.parse_postgresql_audit.source or "";
          maxSlotWalKeepSize = rho.services.postgresql.settings.max_slot_wal_keep_size or null;
          replicaInitScript = tau.systemd.services.postgresql-replica-init.script;
          primarySetupScript = rho.systemd.services.postgresql-setup.postStart;
        }
      );
      prometheusRules = pkgs.writeText "prometheus-rules.json" (
        builtins.concatStringsSep "\n" rho.services.prometheus.rules
      );
      lokiRules = rho.services.loki.configuration.ruler.storage.local.directory;
    in
    {
      checks.postgresql-replication =
        pkgs.runCommand "postgresql-replication-check"
          {
            nativeBuildInputs = [
              pkgs.jq
              pkgs.prometheus.cli
            ];
          }
          ''
            jq -e '.targetRequires | index("postgresql-setup.service") | not' ${state}
            jq -e '.rhoExporter and .tauExporter' ${state}
            jq -e '
              (.rhoExporterFlags | index("--no-collector.stat_replication") != null)
              and
              (.tauExporterFlags | index("--no-collector.stat_replication") != null)
            ' ${state}
            jq -e '.rhoGatusChecks | index("PostgreSQL primary rho") != null' ${state}
            jq -e '.tauGatusChecks | index("PostgreSQL replica tau") != null' ${state}
            jq -e '
              (.etaGatusEndpoints | index("PostgreSQL primary rho") != null)
              and
              (.etaGatusEndpoints | index("PostgreSQL replica tau") != null)
            ' ${state}
            jq -e '.tauAuditTimer | index("timers.target") != null' ${state}
            jq -e '.rhoMetricSource == "prometheus_scrape" and .tauMetricSource == "prometheus_scrape"' ${state}
            jq -e '.metricTransform | contains(".tags.host")' ${state}
            jq -e '.auditTransform | contains("merge!(., parsed)")' ${state}
            jq -e '.maxSlotWalKeepSize == "8GB"' ${state}
            jq -e '.replicaInitScript | contains("primary_slot_name=tau")' ${state}
            jq -e '.primarySetupScript | contains("pg_create_physical_replication_slot")' ${state}

            for alert in \
              PostgresqlDown \
              PostgresqlExporterMissing \
              PostgresqlRoleInvalid \
              PostgresqlReplicaNotStreaming \
              PostgresqlReplicationLagHigh \
              PostgresqlReplicationSlotInactive \
              PostgresqlReplicationSlotWalRisk \
              PostgresqlRoleChanged
            do
              jq -e --arg alert "$alert" \
                '[.groups[].rules[].alert] | index($alert) != null' ${prometheusRules}
            done
            grep -q 'pg_replication_slots_pg_wal_lsn_diff' ${prometheusRules}
            if grep -q 'pg_stat_replication_pg_wal_lsn_diff' ${prometheusRules}; then
              echo "alerts still depend on broken postgres_exporter stat_replication collector" >&2
              exit 1
            fi
            promtool check rules ${prometheusRules}

            grep -R -q 'PostgresqlAuditSnapshotsMissing' ${lokiRules}
            grep -R -q 'PostgresqlReplicaReinitialized' ${lokiRules}
            grep -R -q 'PostgresqlReplicaInitializationFailed' ${lokiRules}
            touch "$out"
          '';
    };
}
