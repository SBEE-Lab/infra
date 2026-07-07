{ config, lib, ... }:
let
  cfg = config.services.rustfs;
  stateDir = "/var/lib/rustfs";
  logDir = "/var/log/rustfs";
in
{
  config = lib.mkIf cfg.enable {
    users.groups.rustfs = { };
    users.users.rustfs = {
      isSystemUser = true;
      group = "rustfs";
      home = stateDir;
      createHome = false;
      description = "RustFS service user";
    };

    sops.secrets.rustfs-access-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };
    sops.secrets.rustfs-secret-key = {
      owner = "rustfs";
      group = "rustfs";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "d /srv/rustfs 0750 rustfs rustfs -"
      "d ${cfg.dataDir} 0750 rustfs rustfs -"
    ];

    systemd.services.rustfs = {
      description = "RustFS S3-compatible object storage";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "srv.mount"
        "sops-install-secrets.service"
      ];
      wants = [ "network-online.target" ];
      requires = [ "sops-install-secrets.service" ];
      unitConfig = {
        RequiresMountsFor = "/srv";
        StartLimitIntervalSec = "5min";
      };

      environment = {
        RUSTFS_ADDRESS = "${cfg.listenAddress}:${toString cfg.apiPort}";
        RUSTFS_CONSOLE_ENABLE = "true";
        RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:${toString cfg.consolePort}";
        RUSTFS_VOLUMES = cfg.dataDir;
        RUSTFS_ACCESS_KEY_FILE = config.sops.secrets.rustfs-access-key.path;
        RUSTFS_SECRET_KEY_FILE = config.sops.secrets.rustfs-secret-key.path;
      };

      serviceConfig = {
        Type = "notify";
        NotifyAccess = "main";
        User = "rustfs";
        Group = "rustfs";
        WorkingDirectory = stateDir;
        StateDirectory = "rustfs";
        LogsDirectory = "rustfs";
        ExecStart = "${cfg.package}/bin/rustfs server";

        LimitNOFILE = 1048576;
        LimitNPROC = 32768;
        TasksMax = "infinity";

        Restart = "on-failure";
        RestartSec = "10s";
        StartLimitBurst = 5;
        TimeoutStartSec = "5min";
        TimeoutStopSec = "45s";
        KillMode = "control-group";
        SendSIGKILL = true;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        UMask = "0077";
        ReadWritePaths = [
          cfg.dataDir
          stateDir
          logDir
        ];

        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
      cfg.apiPort
    ];

    environment.systemPackages = [ cfg.package ];
  };
}
