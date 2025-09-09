{
  config,
  lib,
  ...
}:
let
  cfg = config.services.minio-cluster;
in
{
  options.services.minio-cluster = with lib; {
    enable = mkEnableOption "MinIO distributed cluster";

    nodes = mkOption {
      type = lib.types.listOf lib.types.str;
      description = "List of all MinIO cluster nodes";
      example = [
        "minio1.cluster.local"
        "minio2.cluster.local"
        "minio3.cluster.local"
        "minio4.cluster.local"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.minio = {
      enable = true;

      dataDir = cfg.nodes;

      listenAddress = "0.0.0.0:9000";
      consoleAddress = "127.0.0.1:9001";
      region = "local-cluster";

      rootCredentialsFile = config.sops.templates."minio-credentials".path;
    };

    sops.secrets.minio_root_user = {
      sopsFile = ./secrets.yaml;
      owner = "minio";
      group = "minio";
      mode = "0400";
    };

    sops.secrets.minio_root_password = {
      sopsFile = ./secrets.yaml;
      owner = "minio";
      group = "minio";
      mode = "0400";
    };

    sops.templates."minio-credentials" = {
      content = ''
        MINIO_ROOT_USER=${config.sops.placeholder.minio_root_user}
        MINIO_ROOT_PASSWORD=${config.sops.placeholder.minio_root_password}
      '';
      owner = "minio";
      group = "minio";
      mode = "0400";
    };

    networking.firewall.allowedTCPPorts = [ cfg.ports ];

    users.users.minio = {
      isSystemUser = true;
      group = "minio";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.minio = { };

    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0755 minio minio -" ];
  };
}
