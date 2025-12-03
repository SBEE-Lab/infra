{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.networking.sbee) currentHost hosts;
in {
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    settings = {
      # Base: listen on wg-mgnt only (terraform, replication)
      # buildbot/database.nix will extend this to include wg-serv
      listen_addresses = lib.mkDefault currentHost.wg-mgnt;
      port = 5432;

      wal_level = "replica";
      max_wal_senders = 3;
      wal_keep_size = "1GB";
    };

    ensureDatabases = ["terraform"];
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
    ];

    # Identity map: wheel users -> terraform (for peer auth on rho local)
    identMap = lib.pipe config.users.users [
      (lib.filterAttrs (_: u: lib.elem "wheel" (u.extraGroups or [])))
      lib.attrNames
      (map (user: "tf_map ${user} terraform"))
      (lib.concatStringsSep "\n")
    ];

    authentication = ''
      # Local peer authentication for terraform (wheel users on rho)
      local terraform terraform peer map=tf_map

      # Replication from tau via wg-mgnt
      host replication replicator ${hosts.tau.wg-mgnt}/32 scram-sha-256

      # Terraform backend access from eta (SSH tunnel) via wg-mgnt
      host terraform terraform ${hosts.eta.wg-mgnt}/32 scram-sha-256
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

  systemd.services.postgresql.postStart = let
    psql = "${config.services.postgresql.package}/bin/psql --port=${toString config.services.postgresql.settings.port}";
    terraformModules = ["cloudflare" "github" "vultr"];
  in
    lib.mkAfter ''
      REPLICATOR_PW=$(cat ${config.sops.secrets.pg-replicator-password.path})
      TERRAFORM_PW=$(cat ${config.sops.secrets.pg-terraform-password.path})

      ${psql} -tAc "ALTER USER replicator WITH PASSWORD '$REPLICATOR_PW'" -d postgres
      ${psql} -tAc "ALTER USER terraform WITH PASSWORD '$TERRAFORM_PW'" -d postgres

      # Terraform backend 스키마 및 테이블 초기화
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
        '')
        terraformModules}
    '';

  # Firewall: PostgreSQL from wg-mgnt (terraform, replication)
  networking.firewall.interfaces.wg-mgnt.allowedTCPPorts = [5432];
}
