# Vector service configuration for tau
# - Nextflow webhook ingestion
# - Local Loki for Nextflow logs (wg-admin)
# - Also sends system logs/metrics to rho via default.nix
{
  config,
  lib,
  ...
}:
let
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
in
{
  imports = [
    ./default.nix
  ];

  # Vector:collect nextflow webhook & serve loki
  services.vector = {
    enable = true;

    settings = {
      sources = {
        # Nextflow webhook
        nextflow_weblog = {
          type = "http_server";
          address = "${wgAdminAddr}:9000";
          encoding = "json";
          headers = [ "*" ];
        };
      };

      transforms = {
        # parse nextflow logs
        parse_nextflow = {
          type = "remap";
          inputs = [ "nextflow_weblog" ];
          source = ''
            .log_type = "nextflow"

            # Use exists() for null coalescing - VRL ?? is for error coalescing only
            .project = "unknown"
            if exists(.runName) { .project = to_string!(.runName) }

            .workflow_id = "unknown"
            if exists(.runId) { .workflow_id = to_string!(.runId) }

            .task = "unknown"
            if exists(.name) { .task = to_string!(.name) }

            .status = "UNKNOWN"
            if exists(.status) { .status = to_string!(.status) }

            .hostname = "unknown"
            if exists(.hostname) { .hostname = to_string!(.hostname) }

            .timestamp = now()
            if exists(.submit) { .timestamp = .submit }
          '';
        };
      };

      sinks = {
        # save in loki
        nextflow_logs = {
          type = "loki";
          inputs = [ "parse_nextflow" ];
          endpoint = "http://127.0.0.1:3100";
          encoding.codec = "json";
          labels = {
            log_type = "nextflow";
            project = "{{ project }}";
            status = "{{ status }}";
            hostname = "{{ hostname }}";
          };
        };

        # backup file
        nextflow_backup = {
          type = "file";
          inputs = [ "parse_nextflow" ];
          path = "/var/log/nextflow/weblog-%Y-%m-%d.log";
          encoding.codec = "json";
        };
      };
    };
  };

  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = wgAdminAddr;
        http_listen_port = 3100;
        log_level = "warn";
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
        retention_period = "336h"; # 14 days
        ingestion_burst_size_mb = 32;
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

  networking.firewall.interfaces."wg-admin".allowedTCPPorts = [
    9000 # Nextflow webhook
    3100 # Loki
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/loki 0700 loki loki - -"
    "d /var/log/nextflow 0755 vector vector - -"
  ];

  systemd.services.vector.serviceConfig = {
    SupplementaryGroups = [ "systemd-journal" ];
    MemoryMax = lib.mkForce "512M";
    CPUQuota = lib.mkForce "50%";
  };
}
