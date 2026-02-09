# RAGFlow MySQL database (NixOS native)
#
# Replaces Docker mysql container for:
# - Direct access without docker exec
# - Declarative user/database management
# - Integrated backup via borgbackup
{ config, pkgs, ... }:
let
  dataDir = "/var/lib/ragflow";
  passwordFile = config.sops.secrets.mysql_password.path;
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

  # Ensure sops secrets are available before MySQL starts
  systemd.services.mysql.after = [ "sops-nix.service" ];
  systemd.services.mysql.wants = [ "sops-nix.service" ];

  # Set password from sops secret after MySQL starts
  systemd.services.mysql.postStart =
    let
      mysql = "${config.services.mysql.package}/bin/mysql";
    in
    ''
      # Wait for MySQL to be ready
      for i in $(seq 1 30); do
        if ${mysql} -e "SELECT 1" &>/dev/null; then
          break
        fi
        sleep 1
      done

      # Set password from sops secret
      if [ -f "${passwordFile}" ]; then
        RAGFLOW_PW=$(cat ${passwordFile})

        # Set ragflow user password (use mysql_native_password for compatibility)
        ${mysql} -e "ALTER USER 'ragflow'@'localhost' IDENTIFIED WITH mysql_native_password BY '$RAGFLOW_PW';"

        # Allow connection from RAGFlow Docker network (172.30.0.0/24)
        ${mysql} -e "CREATE USER IF NOT EXISTS 'ragflow'@'172.30.0.%' IDENTIFIED WITH mysql_native_password BY '$RAGFLOW_PW';"
        ${mysql} -e "ALTER USER 'ragflow'@'172.30.0.%' IDENTIFIED WITH mysql_native_password BY '$RAGFLOW_PW';"
        ${mysql} -e "GRANT ALL PRIVILEGES ON rag_flow.* TO 'ragflow'@'172.30.0.%';"
        ${mysql} -e "FLUSH PRIVILEGES;"
      fi

      # Run init-llm.sql (idempotent with INSERT IGNORE)
      [ -f "${dataDir}/init-llm.sql" ] && ${mysql} rag_flow < ${dataDir}/init-llm.sql || true
    '';

  # Allow MySQL from RAGFlow Docker network
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 3306 ];
}
