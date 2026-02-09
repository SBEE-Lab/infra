# RAGFlow MySQL database (NixOS native)
#
# Replaces Docker mysql container for:
# - Direct access without docker exec
# - Declarative user/database management
# - Integrated backup via borgbackup
{
  config,
  lib,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/ragflow";
in
{
  services.mysql = {
    enable = true;
    package = pkgs.mysql80;

    settings.mysqld = {
      # Character set (RAGFlow requirement)
      character-set-server = "utf8mb4";
      collation-server = "utf8mb4_unicode_ci";

      # Connection limits
      max_connections = 1000;

      # Listen on localhost + RAGFlow Docker bridge (172.30.0.1)
      bind-address = "127.0.0.1,172.30.0.1";
    };

    ensureDatabases = [ "rag_flow" ];
    ensureUsers = [
      {
        name = "ragflow";
        ensurePermissions = {
          "rag_flow.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  # Set password and run init SQL after MySQL starts
  # Password is extracted from ragflow-env (.env file)
  systemd.services.mysql.postStart =
    let
      mysql = "${config.services.mysql.package}/bin/mysql";
      envFile = "${dataDir}/.env";
    in
    lib.mkAfter ''
      # Wait for MySQL to be ready
      for i in $(seq 1 30); do
        if ${mysql} -e "SELECT 1" &>/dev/null; then
          break
        fi
        sleep 1
      done

      # Extract password from .env file
      if [ -f "${envFile}" ]; then
        RAGFLOW_PW=$(grep '^MYSQL_PASSWORD=' "${envFile}" | cut -d= -f2-)

        # Set ragflow user password
        ${mysql} -e "ALTER USER 'ragflow'@'localhost' IDENTIFIED BY '$RAGFLOW_PW';"

        # Allow connection from RAGFlow Docker network (172.30.0.0/24)
        ${mysql} -e "CREATE USER IF NOT EXISTS 'ragflow'@'172.30.0.%' IDENTIFIED BY '$RAGFLOW_PW';"
        ${mysql} -e "GRANT ALL PRIVILEGES ON rag_flow.* TO 'ragflow'@'172.30.0.%';"
        ${mysql} -e "FLUSH PRIVILEGES;"
      fi

      # Run init-llm.sql (idempotent with INSERT IGNORE)
      [ -f "${dataDir}/init-llm.sql" ] && ${mysql} rag_flow < ${dataDir}/init-llm.sql || true
    '';

  # Allow MySQL from RAGFlow Docker network
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 3306 ];
}
