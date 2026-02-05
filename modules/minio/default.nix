{ config, ... }:
let
  apiPort = 9000;
  consolePort = 9001;
in
{
  imports = [
    ../gatus/check.nix
  ];

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

    # Credentials from sops
    rootCredentialsFile = config.sops.secrets.minio-credentials.path;
  };

  sops.secrets.minio-credentials = {
    sopsFile = ./secrets.yaml;
    owner = "minio";
    group = "minio";
    mode = "0400";
  };

  # Ensure data directory exists
  systemd.tmpfiles.rules = [
    "d /var/lib/minio 0750 minio minio -"
    "d /var/lib/minio/data 0750 minio minio -"
    "d /var/lib/minio/config 0750 minio minio -"
  ];

  # Firewall: wg-admin (internal services) + localhost
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
    apiPort
    consolePort
  ];
}
