# RAGFlow MinIO storage (NixOS native)
#
# Object storage for RAGFlow documents
{ config, ... }:
let
  apiPort = 9000;
  consolePort = 9001;
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "MinIO";
      group = "storage";
      url = "http://127.0.0.1:${toString apiPort}/minio/health/live";
    }
  ];

  services.minio = {
    enable = true;
    dataDir = [ "/var/lib/minio/data" ];
    configDir = "/var/lib/minio/config";
    listenAddress = "0.0.0.0:${toString apiPort}";
    consoleAddress = "0.0.0.0:${toString consolePort}";
    region = "ap-northeast-2";

    # Credentials from sops template
    rootCredentialsFile = config.sops.templates."minio-credentials".path;
  };

  # Generate MinIO credentials file from atomic secrets
  sops.templates."minio-credentials" = {
    owner = "minio";
    group = "minio";
    mode = "0400";
    content = ''
      MINIO_ROOT_USER=${config.sops.placeholder.minio_user}
      MINIO_ROOT_PASSWORD=${config.sops.placeholder.minio_password}
    '';
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/minio 0750 minio minio -"
    "d /var/lib/minio/data 0750 minio minio -"
    "d /var/lib/minio/config 0750 minio minio -"
  ];

  # Ensure sops secrets are available before MinIO starts
  systemd.services.minio.after = [ "sops-nix.service" ];
  systemd.services.minio.wants = [ "sops-nix.service" ];

  # Firewall: RAGFlow Docker network + wg-admin
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ apiPort ];
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
    apiPort
    consolePort
  ];
}
