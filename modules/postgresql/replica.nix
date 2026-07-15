# PostgreSQL streaming replica configuration for tau
# Replicates from rho (primary) via wg-admin
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  primaryHost = hosts.rho.wg-admin;
  pgPackage = pkgs.postgresql_17;
  pgDataDir = "/var/lib/postgresql/${pgPackage.psqlSchema}";
in
{
  imports = [ ./monitoring.nix ];

  services.postgresql = {
    enable = true;
    package = pgPackage;

    settings = {
      # Replica only serves local monitoring and emergency read-only queries.
      listen_addresses = "localhost";
      port = 5432;
      hot_standby = true;
    };
  };

  # Initialize replica from primary before PostgreSQL starts.
  systemd.services.postgresql-replica-init = {
    description = "Initialize PostgreSQL streaming replica";
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "postgresql.service" ];
    before = [ "postgresql.service" ];
    requiredBy = [ "postgresql.service" ];

    path = [
      pgPackage
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      Group = "postgres";
      RuntimeDirectory = "postgresql-replica-init";
      RuntimeDirectoryMode = "0700";
    };

    script = ''
      set -euo pipefail
      PGDATA=${lib.escapeShellArg pgDataDir}
      PASSWORD_FILE=${lib.escapeShellArg config.sops.secrets.pg-replicator-password.path}
      PGPASSFILE="$RUNTIME_DIRECTORY/pgpass"

      audit_event() {
        jq -nc --arg event "$1" '{
          host: "tau",
          log_type: "postgresql_audit",
          event: $event,
          configured_role: "replica"
        }'
      }
      trap 'audit_event replica_initialization_failed' ERR

      # Keep credentials out of primary_conninfo and command arguments. pgpass
      # requires backslash escaping for its two separator characters.
      escaped_password=$(sed -e 's/\\/\\\\/g' -e 's/:/\\:/g' "$PASSWORD_FILE")
      printf '%s:%s:*:replicator:%s\n' ${lib.escapeShellArg primaryHost} 5432 "$escaped_password" > "$PGPASSFILE"
      chmod 600 "$PGPASSFILE"

      if [ -f "$PGDATA/PG_VERSION" ]; then
        if [ "$(cat "$PGDATA/PG_VERSION")" != ${lib.escapeShellArg pgPackage.psqlSchema} ] \
          || [ ! -f "$PGDATA/standby.signal" ]; then
          echo "Existing PostgreSQL data directory is not a PostgreSQL ${pgPackage.psqlSchema} standby" >&2
          audit_event replica_initialization_failed
          trap - ERR
          exit 1
        fi
        audit_event replica_configuration_refreshed
      else
        rm -rf "$PGDATA"
        audit_event replica_basebackup_started
        PGPASSFILE="$PGPASSFILE" pg_basebackup \
          -h ${lib.escapeShellArg primaryHost} \
          -p 5432 \
          -U replicator \
          -D "$PGDATA" \
          -Fp -Xs -P -R \
          --slot=tau
        audit_event replica_basebackup_completed
      fi

      cp "$PGPASSFILE" "$PGDATA/.pgpass"
      chmod 600 "$PGDATA/.pgpass"
      cat > "$PGDATA/postgresql.auto.conf" <<'CONF'
      primary_conninfo = 'host=${primaryHost} port=5432 user=replicator passfile=${pgDataDir}/.pgpass application_name=tau sslmode=prefer'
      primary_slot_name=tau
      CONF
      chmod 600 "$PGDATA/postgresql.auto.conf"
      trap - ERR
    '';
  };

  sops.secrets.pg-replicator-password = {
    owner = "postgres";
    group = "postgres";
  };

  # NixOS' PostgreSQL target requires postgresql-setup by default. Replica
  # setup waits forever for recovery to end, so remove only that target edge
  # while retaining postgresql.service as boot dependency.
  systemd.services.postgresql-setup.enable = false;
  systemd.targets.postgresql.requires = lib.mkForce [ "postgresql.service" ];
}
