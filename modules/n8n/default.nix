{ config, ... }:
let
  inherit (config.networking.sbee) hosts;
  n8nDomain = "n8n.sjanglab.org";
in
{
  services.n8n = {
    enable = true;
    openFirewall = false;
    environment = {
      # Timezone (overrides system default)
      GENERIC_TIMEZONE = "Asia/Seoul";

      # Editor URL for webhooks
      N8N_EDITOR_BASE_URL = "https://${n8nDomain}";
      WEBHOOK_URL = "https://${n8nDomain}";

      # Disable telemetry
      N8N_DIAGNOSTICS_ENABLED = false;
      N8N_VERSION_NOTIFICATIONS_ENABLED = false;

      # Executions pruning
      EXECUTIONS_DATA_PRUNE = "true";
      EXECUTIONS_DATA_MAX_AGE = "336"; # 2 weeks in hours

      # PostgreSQL (rho primary)
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = hosts.rho.wg-admin;
      DB_POSTGRESDB_PORT = "5432";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";

      # Password via _FILE suffix (auto-handled by systemd credentials)
      DB_POSTGRESDB_PASSWORD_FILE = config.sops.secrets.n8n-db-password.path;
    };
  };

  sops.secrets.n8n-db-password = {
    sopsFile = ./secrets.yaml;
  };

  # Firewall: wg-admin (for eta reverse proxy), tailscale (for direct UI access)
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5678 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 5678 ];
}
