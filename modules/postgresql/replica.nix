# PostgreSQL streaming replica configuration for tau
# Replicates from rho (primary) via wg-admin
{
  config,
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
    ];

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

            # Already initialized - just update connection info
            if [ -f "$PGDATA/PG_VERSION" ]; then
              echo "Replica already initialized, updating primary_conninfo..."
            else
              # Clean and initialize from primary
              rm -rf "$PGDATA"
              echo "Initializing replica from primary ${primaryHost}..."

              PGPASSWORD=$(cat "$PASSWORD_FILE") pg_basebackup \
                -h ${primaryHost} \
                -p 5432 \
                -U replicator \
                -D "$PGDATA" \
                -Fp -Xs -P -R

              echo "Replica initialization complete."
            fi

            # Update primary_conninfo with current password
            PASSWORD=$(cat "$PASSWORD_FILE")
            cat > "$PGDATA/postgresql.auto.conf" << 'CONF'
      primary_conninfo = 'host=${primaryHost} port=5432 user=replicator password=PASSWORD_PLACEHOLDER application_name=tau sslmode=prefer'
      CONF
            sed -i "s/PASSWORD_PLACEHOLDER/$PASSWORD/" "$PGDATA/postgresql.auto.conf"
            chmod 600 "$PGDATA/postgresql.auto.conf"
    '';
  };

  sops.secrets.pg-replicator-password = {
    owner = "postgres";
    group = "postgres";
  };

  # Disable postgresql-setup on replica - it waits for recovery to complete,
  # but replicas are always in recovery mode
  systemd.services.postgresql-setup.enable = false;
}
