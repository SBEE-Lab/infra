{ pkgs, ... }:
let
  domain = "rag.sjanglab.org";
  dataDir = "/var/lib/ragflow";
in
{
  imports = [
    ../minio # MinIO dependency (NixOS native)
    ../gatus/check.nix
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

  # Kernel settings for Elasticsearch
  boot.kernel.sysctl."vm.max_map_count" = 262144;

  # Create data directory and copy docker-compose file + nginx config
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
    "d ${dataDir}/nginx 0755 root root -"
    "L+ ${dataDir}/docker-compose.yml - - - - ${./docker-compose.yml}"
    "L+ ${dataDir}/nginx/ragflow.conf - - - - ${./nginx/ragflow.conf}"
    "L+ ${dataDir}/nginx/entrypoint-wrapper.sh - - - - ${./nginx/entrypoint-wrapper.sh}"
    "L+ ${dataDir}/service_conf.yaml.template - - - - ${./service_conf.yaml.template}"
  ];

  # Environment file with secrets
  sops.secrets.ragflow-env = {
    sopsFile = ./secrets.yaml;
    path = "${dataDir}/.env";
  };

  # Systemd service to manage docker-compose
  systemd.services.ragflow = {
    description = "RAGFlow RAG Engine";
    after = [
      "docker.service"
      "network-online.target"
      "minio.service"
    ];
    requires = [ "docker.service" ];
    wants = [
      "network-online.target"
      "minio.service"
    ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker-compose ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = dataDir;
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d --remove-orphans";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      ExecReload = "${pkgs.docker-compose}/bin/docker-compose up -d --remove-orphans";
      TimeoutStartSec = "30min";
    };
  };

  # Nginx reverse proxy (Tailscale only)
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];

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
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
