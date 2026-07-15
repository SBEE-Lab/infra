{
  config,
  lib,
  ...
}:
{
  imports = [
    ../gatus/check.nix
    ./loki-rules.nix
  ];

  gatusCheck.push = [
    {
      name = "Loki";
      group = "monitoring";
      url = "http://127.0.0.1:3100/ready";
    }
  ];

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        # Query API is rho-local only; ingest is re-exposed on wg-admin by
        # modules/monitoring/ingest-proxy.nix, which path-filters to push.
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
      };

      common = {
        path_prefix = config.services.loki.dataDir;
        storage.filesystem = {
          chunks_directory = "${config.services.loki.dataDir}/chunks";
          rules_directory = "${config.services.loki.dataDir}/rules";
        };
        replication_factor = 1;
        ring.instance_addr = "127.0.0.1";
        ring.kvstore.store = "inmemory";
      };

      limits_config = {
        retention_period = "168h"; # 7 days
        ingestion_burst_size_mb = 16;

        # Audit streams keep 90 days; headscale_nodes snapshots are
        # repetitive state and stay on the 7-day default.
        retention_stream = [
          {
            selector = ''{log_type=~"ssh|ssh_bastion|access_audit|audit|authentik|headscale|postgresql_audit"}'';
            priority = 1;
            period = "2160h"; # 90 days
          }
        ];
      };

      compactor = {
        retention_enabled = true;
        working_directory = "${config.services.loki.dataDir}/compactor";
        delete_request_store = "filesystem";
      };

      schema_config.configs = [
        {
          from = "2025-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index.prefix = "index_";
          index.period = "24h";
        }
      ];
    };
  };
  users.users.loki = lib.mkIf config.services.loki.enable {
    isSystemUser = true;
    group = "loki";
  };

  users.groups.loki = lib.mkIf config.services.loki.enable { };

  systemd.tmpfiles.rules = [
    "d ${config.services.loki.dataDir} 0700 loki loki - -"
    "d /var/lib/loki 0700 loki loki - -"
  ];

  systemd.services.loki = lib.mkIf config.services.loki.enable {
    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
    };
  };

}
