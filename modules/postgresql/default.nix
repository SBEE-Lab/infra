{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) currentHost hosts;
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "PostgreSQL";
      group = "db";
      systemdService = "postgresql.service";
    }
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    settings = {
      # Base: listen on wg-admin only (terraform, replication, buildbot)
      listen_addresses = lib.mkForce currentHost.wg-admin;
      port = 5432;

      wal_level = "replica";
      max_wal_senders = 3;
      wal_keep_size = "1GB";
    };

    ensureDatabases = [
      "terraform"
      "nextcloud"
      "n8n"
    ];
    ensureUsers = [
      {
        name = "terraform";
        ensureDBOwnership = true;
      }
      {
        name = "replicator";
        ensureClauses = {
          login = true;
          replication = true;
        };
      }
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
      {
        name = "n8n";
        ensureDBOwnership = true;
      }
    ];

    # Identity map: wheel users -> terraform (for peer auth on rho local)
    identMap = lib.pipe config.users.users [
      (lib.filterAttrs (_: u: lib.elem "wheel" (u.extraGroups or [ ])))
      lib.attrNames
      (map (user: "tf_map ${user} terraform"))
      (lib.concatStringsSep "\n")
    ];

    authentication = ''
      # Local peer authentication for terraform (wheel users on rho)
      local terraform terraform peer map=tf_map

      # Replication from tau via wg-admin
      host replication replicator ${hosts.tau.wg-admin}/32 scram-sha-256

      # Terraform backend access from eta (SSH tunnel) via wg-admin
      host terraform terraform ${hosts.eta.wg-admin}/32 scram-sha-256

      # Nextcloud database access from tau via wg-admin
      host nextcloud nextcloud ${hosts.tau.wg-admin}/32 scram-sha-256

      # n8n database access from tau via wg-admin
      host n8n n8n ${hosts.tau.wg-admin}/32 scram-sha-256
    '';
  };

  # PostgreSQL backup is handled by borgbackup/rho/client.nix
  # which runs pg_dumpall before borg backup

  sops.secrets.pg-replicator-password = {
    owner = "postgres";
    group = "postgres";
  };
  sops.secrets.pg-terraform-password = {
    owner = "postgres";
    group = "postgres";
  };
  sops.secrets.pg-nextcloud-password = {
    owner = "postgres";
    group = "postgres";
  };
  sops.secrets.pg-n8n-password = {
    owner = "postgres";
    group = "postgres";
  };

  systemd.services.postgresql.postStart =
    let
      psql = "${config.services.postgresql.package}/bin/psql --port=${toString config.services.postgresql.settings.port}";
      terraformModules = [
        "cloudflare"
        "github"
        "vultr"
      ];
    in
    # mkOrder 2000 ensures this runs after ensureUsers (which uses mkAfter = 1500)
    lib.mkOrder 2000 ''
      REPLICATOR_PW=$(cat ${config.sops.secrets.pg-replicator-password.path})
      TERRAFORM_PW=$(cat ${config.sops.secrets.pg-terraform-password.path})
      NEXTCLOUD_PW=$(cat ${config.sops.secrets.pg-nextcloud-password.path})
      N8N_PW=$(cat ${config.sops.secrets.pg-n8n-password.path})

      # Set passwords only if roles exist (ensureUsers may run in parallel)
      ${psql} -tAc "SELECT 1 FROM pg_roles WHERE rolname='replicator'" -d postgres | grep -q 1 && \
        ${psql} -tAc "ALTER USER replicator WITH PASSWORD '$REPLICATOR_PW'" -d postgres
      ${psql} -tAc "SELECT 1 FROM pg_roles WHERE rolname='terraform'" -d postgres | grep -q 1 && \
        ${psql} -tAc "ALTER USER terraform WITH PASSWORD '$TERRAFORM_PW'" -d postgres
      ${psql} -tAc "SELECT 1 FROM pg_roles WHERE rolname='nextcloud'" -d postgres | grep -q 1 && \
        ${psql} -tAc "ALTER USER nextcloud WITH PASSWORD '$NEXTCLOUD_PW'" -d postgres
      ${psql} -tAc "SELECT 1 FROM pg_roles WHERE rolname='n8n'" -d postgres | grep -q 1 && \
        ${psql} -tAc "ALTER USER n8n WITH PASSWORD '$N8N_PW'" -d postgres

      ${lib.concatMapStringsSep "\n" (mod: ''
        ${psql} -d terraform <<SQL
          CREATE SCHEMA IF NOT EXISTS ${mod} AUTHORIZATION terraform;
          CREATE SEQUENCE IF NOT EXISTS ${mod}.global_states_id_seq OWNED BY NONE;
          ALTER SEQUENCE ${mod}.global_states_id_seq OWNER TO terraform;
          CREATE TABLE IF NOT EXISTS ${mod}.states (
            id bigint NOT NULL DEFAULT nextval('${mod}.global_states_id_seq') PRIMARY KEY,
            name text UNIQUE,
            data text
          );
          ALTER TABLE ${mod}.states OWNER TO terraform;
          CREATE TABLE IF NOT EXISTS ${mod}.locks (
            id text PRIMARY KEY,
            info text
          );
          ALTER TABLE ${mod}.locks OWNER TO terraform;
        SQL
      '') terraformModules}
    '';

  # Firewall: PostgreSQL from wg-admin (terraform, replication)
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5432 ];
}
