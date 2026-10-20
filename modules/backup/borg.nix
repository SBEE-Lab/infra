{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostName = config.networking.hostName;
  mountpoint = config.disko.xfsMdadm.arrays.data.mountpoint;
  postgresEnabled = config.services.postgresql.enable;
  lockDir = "/run/infra-borg-local";
  excludedPaths = [
    mountpoint
    "/dev"
    "/home"
    "/proc"
    "/run"
    "/sys"
  ]
  ++ lib.optional (
    config.disko.xfsMdadm.arrays ? workspace
  ) config.disko.xfsMdadm.arrays.workspace.mountpoint
  ++ lib.optional postgresEnabled config.services.postgresql.dataDir;
  job = config.services.borgbackup.jobs.local;
  acquireLock = ''
    exec 9>${lockDir}/workflow.lock
    ${pkgs.util-linux}/bin/flock --exclusive --timeout 21600 9
  '';
in
{
  sops.secrets.borg-passphrase = { };

  services.borgbackup.jobs.local = {
    repo = "${mountpoint}/borg/${hostName}";
    paths = [
      "/"
      "/boot"
    ];
    exclude = map (path: "pp:${path}") excludedPaths;
    preHook = acquireLock;
    readWritePaths = [ lockDir ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.borg-passphrase.path}";
    };
    compression = "auto,zstd";
    # Keep warning results distinct from clean, complete backups.
    failOnWarnings = true;
    # Recovery keys belong to the verified repositories; never replace them implicitly.
    doInit = false;
    startAt = "*-*-* 05:30:00 Asia/Seoul";
    persistentTimer = true;
    extraCreateArgs = [
      "--one-file-system"
      "--stats"
    ];
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };
  };

  systemd.timers.borgbackup-job-local.timerConfig.RandomizedDelaySec = 0;

  systemd.services.borgbackup-job-local = {
    requires = lib.optional postgresEnabled "postgresqlBackup.service";
    after = lib.optional postgresEnabled "postgresqlBackup.service";
    unitConfig.RequiresMountsFor = [ "/boot" ];
  };

  systemd.tmpfiles.rules = [
    "d ${lockDir} 0700 root root - -"
  ];

  systemd.services.borgbackup-verify-local = {
    description = "Verify local Borg repository integrity";
    unitConfig.RequiresMountsFor = [ job.repo ];
    environment = builtins.removeAttrs config.systemd.services.borgbackup-job-local.environment [
      "PATH"
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "12h";
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      UMask = "0077";
      ProtectSystem = "strict";
      PrivateTmp = true;
      PrivateNetwork = true;
      PrivateDevices = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      ReadWritePaths = [
        lockDir
        job.repo
        "/root/.config/borg"
        "/root/.cache/borg"
      ];
    };
    script = ''
      set -euo pipefail
      ${acquireLock}
      exec ${config.services.borgbackup.package}/bin/borg check --verify-data
    '';
  };

  systemd.timers.borgbackup-verify-local = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun *-*-* 09:00:00 Asia/Seoul";
      Persistent = true;
      RandomizedDelaySec = 0;
    };
  };

  # Raw PGDATA is not a consistent live backup; dump all local databases and roles.
  services.postgresqlBackup = lib.mkIf postgresEnabled {
    enable = true;
    backupAll = true;
    compression = "none";
    startAt = [ ];
  };
  systemd.services.postgresqlBackup = lib.mkIf postgresEnabled {
    after = [ "postgresql.service" ];
  };
}
