{ config, pkgs, ... }:
let
  domain = "rag.sjanglab.org";
  dataDir = "/var/lib/ragflow";
in
{
  imports = [
    ./mysql.nix # MySQL database (NixOS native)
    ./opensearch.nix # OpenSearch (NixOS native, ES-compatible)
    ./redis.nix # Redis/Valkey (NixOS native)
    ./minio.nix # MinIO storage (NixOS native)
    ../gatus/check.nix
    ../acme/sync.nix
  ];

  gatusCheck.push = [
    {
      name = "RAGFlow";
      group = "ai";
      url = "http://127.0.0.1:8080/";
    }
  ];

  # Enable Docker
  virtualisation.docker.enable = true;

  # Kernel settings for OpenSearch
  boot.kernel.sysctl."vm.max_map_count" = 262144;

  # Create data directory and config files
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
    "d ${dataDir}/logs 0755 root root -"
    "d ${dataDir}/nginx 0755 root root -"
    "L+ ${dataDir}/nginx/ragflow.conf - - - - ${./nginx/ragflow.conf}"
    "L+ ${dataDir}/nginx/entrypoint-wrapper.sh - - - - ${./nginx/entrypoint-wrapper.sh}"
    "L+ ${dataDir}/service_conf.yaml.template - - - - ${./service_conf.yaml.template}"
    "L+ ${dataDir}/init-llm.sql - - - - ${./init-llm.sql}"
    "d ${dataDir}/patches 0755 root root -"
    "L+ ${dataDir}/patches/apply.py - - - - ${./patches/apply.py}"
  ];

  # Atomic secrets from sops
  sops.secrets = {
    mysql_password = {
      sopsFile = ./secrets.yaml;
      owner = "mysql";
    };
    redis_password = {
      sopsFile = ./secrets.yaml;
      owner = "redis-ragflow";
    };
    minio_user.sopsFile = ./secrets.yaml;
    minio_password.sopsFile = ./secrets.yaml;
    oidc_client_id.sopsFile = ./secrets.yaml;
    oidc_client_secret.sopsFile = ./secrets.yaml;
    ragflow_secret_key.sopsFile = ./secrets.yaml;
  };

  # Generate ragflow-env from atomic secrets (no duplication in secrets.yaml)
  sops.templates."ragflow-env" = {
    path = "${dataDir}/.env";
    content = ''
      MYSQL_PASSWORD=${config.sops.placeholder.mysql_password}
      REDIS_PASSWORD=${config.sops.placeholder.redis_password}
      MINIO_USER=${config.sops.placeholder.minio_user}
      MINIO_PASSWORD=${config.sops.placeholder.minio_password}
      OIDC_CLIENT_ID=${config.sops.placeholder.oidc_client_id}
      OIDC_CLIENT_SECRET=${config.sops.placeholder.oidc_client_secret}
      RAGFLOW_SECRET_KEY=${config.sops.placeholder.ragflow_secret_key}
    '';
  };

  # Docker network for RAGFlow (fixed subnet for host access)
  systemd.services.ragflow-network = {
    description = "Create RAGFlow Docker network";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    before = [ "docker-ragflow.service" ];
    requiredBy = [ "docker-ragflow.service" ];

    path = [ pkgs.docker ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "ragflow-network-create" ''
        docker network inspect ragflow >/dev/null 2>&1 || \
          docker network create \
            --driver bridge \
            --subnet 172.30.0.0/24 \
            --gateway 172.30.0.1 \
            -o com.docker.network.bridge.name=br-ragflow \
            ragflow
      '';
      ExecStop = "${pkgs.docker}/bin/docker network rm ragflow || true";
    };
  };

  # RAGFlow container via oci-containers
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.ragflow = {
    # Pinned to latest (2026-02-08) for WebDAV async generator fix (f56bceb2)
    image = "infiniflow/ragflow@sha256:652a00a14036c859f1d72c90bbd242f33afb085a43749822cd5d9a58f463ea53";
    ports = [
      "127.0.0.1:8080:80"
      "127.0.0.1:9380:9380"
    ];
    volumes = [
      "${dataDir}/logs:/ragflow/logs"
      "${dataDir}/nginx/ragflow.conf:/etc/nginx/conf.d/ragflow.conf:ro"
      "${dataDir}/nginx/entrypoint-wrapper.sh:/ragflow/entrypoint-wrapper.sh:ro"
      "${dataDir}/service_conf.yaml.template:/ragflow/conf/service_conf.yaml.template:ro"
      "${dataDir}/patches/apply.py:/ragflow/patches/apply.py:ro"
    ];
    entrypoint = "/bin/bash";
    cmd = [ "/ragflow/entrypoint-wrapper.sh" ];
    environmentFiles = [ "${dataDir}/.env" ];
    environment = {
      DOC_ENGINE = "opensearch";
      DEVICE = "cpu";
      # All services on NixOS host via Docker bridge gateway
      ES_HOST = "172.30.0.1";
      ES_PORT = "9200";
      MYSQL_HOST = "172.30.0.1";
      MYSQL_PORT = "3306";
      MYSQL_DBNAME = "rag_flow";
      MYSQL_USER = "ragflow";
      MINIO_HOST = "172.30.0.1";
      MINIO_PORT = "9000";
      REDIS_HOST = "172.30.0.1";
      REDIS_PORT = "6379";
      TZ = "Asia/Seoul";
    };
    extraOptions = [
      "--network=ragflow"
      "--add-host=vllm.sjanglab.org:100.64.0.1"
      "--add-host=tei.sjanglab.org:100.64.0.1"
      "--add-host=cloud.sjanglab.org:100.64.0.3"
    ];
  };

  # Add dependencies to the generated docker-ragflow service
  systemd.services.docker-ragflow = {
    after = [
      "mysql.service"
      "opensearch.service"
      "redis-ragflow.service"
      "minio.service"
      "ragflow-network.service"
    ];
    requires = [
      "mysql.service"
      "opensearch.service"
      "redis-ragflow.service"
      "ragflow-network.service"
    ];
    wants = [ "minio.service" ];
  };

  # Initialize custom LLM models after RAGFlow starts
  # RAGFlow populates llm table on startup, so we add our models afterward
  systemd.services.ragflow-init-llm = {
    description = "Initialize RAGFlow custom LLM models";
    after = [
      "docker-ragflow.service"
      "sops-nix.service"
    ];
    requires = [ "docker-ragflow.service" ];
    wants = [ "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];

    path = [
      config.services.mysql.package
      pkgs.curl
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "mysql";
      Group = "mysql";
      ExecStart = pkgs.writeShellScript "ragflow-init-llm" ''
        set -euo pipefail

        # Wait for RAGFlow API to be ready
        for i in $(seq 1 60); do
          if curl -sf http://127.0.0.1:9380/v1/system/version >/dev/null 2>&1; then
            break
          fi
          sleep 2
        done
        sleep 5  # Extra wait for llm table population

        # Use MYSQL_PWD env var to avoid password in process list
        MYSQL_PWD="$(cat ${config.sops.secrets.mysql_password.path})" \
          mysql -u ragflow rag_flow < ${dataDir}/init-llm.sql

        MYSQL_PWD="$(cat ${config.sops.secrets.mysql_password.path})" \
          mysql -u ragflow rag_flow -e \
          "UPDATE tenant_llm SET llm_factory='HuggingFace' WHERE llm_factory='Huggingface';"
      '';
    };
  };

  # ACME certificate receiver
  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-ragflow";
    }
  ];

  # Nginx reverse proxy (Tailscale only, HTTPS)
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${domain}/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 500M;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
        '';
      };
    };
  };

  # Firewall: Tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
