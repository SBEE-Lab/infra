# PostgreSQL streaming replica configuration for tau
# Replicates from rho (primary) via wg-mgnt
{
  config,
  pkgs,
  ...
}: let
  inherit (config.networking.sbee) hosts;
  primaryHost = hosts.rho.wg-mgnt;
  pgPackage = pkgs.postgresql_17;
  pgDataDir = "/var/lib/postgresql/${pgPackage.psqlSchema}";
in {
  services.postgresql = {
    enable = true;
    package = pgPackage;

    settings = {
      # Listen on localhost only (replica doesn't need external access)
      listen_addresses = "localhost";
      port = 5432;

      # Hot standby allows read-only queries on the replica
      hot_standby = true;
    };
  };

  # Initialize replica from primary before PostgreSQL starts
  # This runs pg_basebackup on first boot, then maintains standby.signal
  systemd.services.postgresql-replica-init = {
    description = "Initialize PostgreSQL streaming replica";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["postgresql.service"];
    before = ["postgresql.service"];
    requiredBy = ["postgresql.service"];

    path = [pgPackage pkgs.coreutils];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      Group = "postgres";
    };

    script = ''
      set -euo pipefail
      PGDATA="${pgDataDir}"
      PASSWORD_FILE="${config.sops.secrets.pg-replicator-password.path}"

      # Create data directory if needed
      if [ ! -d "$PGDATA" ]; then
        mkdir -p "$PGDATA"
        chmod 700 "$PGDATA"
      fi

      # Initialize from primary if not already done
      if [ ! -f "$PGDATA/PG_VERSION" ]; then
        echo "Initializing replica from primary ${primaryHost}..."
        export PGPASSFILE="$PGDATA/.pgpass"
        echo "${primaryHost}:5432:replication:replicator:$(cat $PASSWORD_FILE)" > "$PGPASSFILE"
        chmod 600 "$PGPASSFILE"

        pg_basebackup \
          -h ${primaryHost} \
          -p 5432 \
          -U replicator \
          -D "$PGDATA" \
          -Fp -Xs -P -R

        rm -f "$PGPASSFILE"
        echo "Replica initialization complete."
      fi

      # Ensure standby.signal exists (marks this as a replica)
      if [ ! -f "$PGDATA/standby.signal" ]; then
        touch "$PGDATA/standby.signal"
      fi

      # Update primary_conninfo with current password
      PASSWORD=$(cat "$PASSWORD_FILE")
      cat > "$PGDATA/postgresql.auto.conf" << EOF
      primary_conninfo = 'host=${primaryHost} port=5432 user=replicator password=$PASSWORD application_name=tau sslmode=prefer'
      EOF
      chmod 600 "$PGDATA/postgresql.auto.conf"
    '';
  };

  sops.secrets.pg-replicator-password = {
    owner = "postgres";
    group = "postgres";
  };
}
