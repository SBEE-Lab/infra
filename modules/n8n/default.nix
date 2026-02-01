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
      N8N_DIAGNOSTICS_ENABLED = "false";
      N8N_VERSION_NOTIFICATIONS_ENABLED = "false";

      # Executions pruning
      EXECUTIONS_DATA_PRUNE = "true";
      EXECUTIONS_DATA_MAX_AGE = "336"; # 2 weeks in hours

      # PostgreSQL (rho primary)
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = hosts.rho.wg-admin;
      DB_POSTGRESDB_PORT = "5432";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";

      # Password via _FILE suffix (read from systemd credentials)
      DB_POSTGRESDB_PASSWORD_FILE = "%d/db-password";
    };
  };

  sops.secrets.n8n-db-password = {
    sopsFile = ./secrets.yaml;
  };

  systemd.services.n8n.serviceConfig.LoadCredential = [
    "db-password:${config.sops.secrets.n8n-db-password.path}"
  ];

  # Firewall: wg-admin (for eta reverse proxy)
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5678 ];

  # HTTPS via nginx for Tailscale access (split DNS)
  # Certificate synced from eta via rsync (same pattern as nextcloud)

  # Public key for acme-sync from eta
  users.users.acme-sync-n8n = {
    isSystemUser = true;
    group = "acme-sync-n8n";
    home = "/var/lib/acme/${n8nDomain}";
    shell = "/run/current-system/sw/bin/bash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7mZ/UfOMpnrHaIigljsGWXCQAovWezdPpA3WQy1Qgu acme-sync@eta"
    ];
  };
  users.groups.acme-sync-n8n.members = [ "nginx" ];

  systemd.tmpfiles.rules = [
    "d /var/lib/acme/${n8nDomain} 0750 acme-sync-n8n acme-sync-n8n - -"
  ];

  # Reload nginx when certificates are updated
  systemd.services.acme-sync-n8n-reload-nginx = {
    description = "Reload nginx after n8n certificate sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/bin/systemctl reload nginx";
    };
  };
  systemd.paths.acme-sync-n8n-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "/var/lib/acme/${n8nDomain}/fullchain.pem";
      Unit = "acme-sync-n8n-reload-nginx.service";
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${n8nDomain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/${n8nDomain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${n8nDomain}/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:5678";
        proxyWebsockets = true;
      };
    };
  };

  # Firewall: HTTPS for Tailscale
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
