# Vector service configuration for tau
# - Nextflow webhook ingestion
# - Local Loki for Nextflow logs (wg-serv)
# - Also sends system logs/metrics to rho via default.nix
{
  config,
  lib,
  ...
}: let
  wgServAddr = config.networking.sbee.currentHost.wg-serv;
in {
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
          address = "${wgServAddr}:9000";
          encoding = "json";
          headers = ["*"];
        };
      };

      transforms = {
        # parse nextflow logs
        parse_nextflow = {
          type = "remap";
          inputs = ["nextflow_weblog"];
          source = ''
            .log_type = "nextflow"
            .project = .runName ?? "unknown"
            .workflow_id = .runId ?? "unknown"
            .task = .name ?? "unknown"
            .status = .status ?? "UNKNOWN"
            .hostname = .hostname ?? "unknown"
            .timestamp = .submit ?? now()
          '';
        };
      };

      sinks = {
        # save in loki
        nextflow_logs = {
          type = "loki";
          inputs = ["parse_nextflow"];
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
          inputs = ["parse_nextflow"];
          path = "/var/log/nextflow/weblog-%Y-%m-%d.log";
          encoding.codec = "ndjson";
        };
      };
    };
  };

  # Loki 서버 (Nextflow 전용)
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server = {
        http_listen_address = wgServAddr;
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

  networking.firewall.interfaces."wg-serv".allowedTCPPorts = [
    9000 # Nextflow webhook
    3100 # Loki
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/loki 0700 loki loki - -"
    "d /var/log/nextflow 0755 vector vector - -"
  ];

  systemd.services.vector.serviceConfig = {
    SupplementaryGroups = ["systemd-journal"];
    MemoryMax = lib.mkForce "512M";
    CPUQuota = lib.mkForce "50%";
  };
}
