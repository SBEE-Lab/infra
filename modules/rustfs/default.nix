{
  config,
  inputs,
  pkgs,
  ...
}:
let
  apiPort = 9100;
  consolePort = 9101;
  listenAddress = config.networking.sbee.currentHost.wg-admin;
  rustfsPkg = inputs.rustfs.packages.${pkgs.system}.default;
  dataDir = "/srv/rustfs/data";
  stateDir = "/var/lib/rustfs";
  logDir = "/var/log/rustfs";
in
{
  imports = [
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "RustFS ${config.networking.hostName}";
      group = "storage";
      url = "http://${listenAddress}:${toString apiPort}/health/ready";
    }
  ];

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
    "d ${dataDir} 0750 rustfs rustfs -"
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
      RUSTFS_ADDRESS = "${listenAddress}:${toString apiPort}";
      RUSTFS_CONSOLE_ENABLE = "true";
      RUSTFS_CONSOLE_ADDRESS = "127.0.0.1:${toString consolePort}";
      RUSTFS_VOLUMES = dataDir;
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
      ExecStart = "${rustfsPkg}/bin/rustfs server";

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
        dataDir
        stateDir
        logDir
      ];

      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [
    apiPort
  ];

  environment.systemPackages = [ rustfsPkg ];
}
