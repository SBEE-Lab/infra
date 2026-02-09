{ pkgs, ... }:
let
  domain = "rag.sjanglab.org";
  dataDir = "/var/lib/ragflow";
in
{
  imports = [
    ./mysql.nix # MySQL database (NixOS native)
    ./opensearch.nix # OpenSearch (NixOS native, ES-compatible)
    ./redis.nix # Redis/Valkey (NixOS native)
    ../minio # MinIO dependency (NixOS native)
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
  ];

  # Environment file with secrets
  sops.secrets.ragflow-env = {
    sopsFile = ./secrets.yaml;
    path = "${dataDir}/.env";
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
    image = "infiniflow/ragflow:v0.23.1";
    ports = [
      "127.0.0.1:8080:80"
      "127.0.0.1:9380:9380"
    ];
    volumes = [
      "${dataDir}/logs:/ragflow/logs"
      "${dataDir}/nginx/ragflow.conf:/etc/nginx/conf.d/ragflow.conf:ro"
      "${dataDir}/nginx/entrypoint-wrapper.sh:/ragflow/entrypoint-wrapper.sh:ro"
      "${dataDir}/service_conf.yaml.template:/ragflow/conf/service_conf.yaml.template:ro"
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
