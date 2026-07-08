{
  config,
  lib,
  pkgs,
  ...
}:
let
  dbSyncDatabases = {
    blast-nr.enable = true;
    blast-nt.enable = true;
    blast-swissprot.enable = true;
    uniref90.enable = true;
    uniref100.enable = true;
    pdb.enable = true;
    pdb-mmcif.enable = true;
    rnacentral.enable = true;
    pfam.enable = true;
    rfam.enable = true;
    # alphafold.enable = true;  # Very large, enable when needed
  };

  psiProtected = lib.sbee.backup.contracts.psiProtected;
  protectedRepository = psiProtected.repository;
  resticRepository = "s3:http://${config.networking.sbee.hosts.tau.wg-admin}:9100/${psiProtected.bucket}/${psiProtected.prefix}";
  blobsQuotaBytes = 200 * 1024 * 1024 * 1024;
  projectBudgetBytes = 10 * 1024 * 1024 * 1024;
  sharedBackupSecretsFile = ../hosts/shared/psi-backup.yaml;
  resticEnvTemplateName = role: "restic-${protectedRepository}-${role}-env";

  monitoredSystemdUnits =
    map (name: "db-sync-${name}.service") (builtins.attrNames dbSyncDatabases)
    ++ [
      "backup-guard-${protectedRepository}.service"
      "restic-backups-${protectedRepository}.service"
      "restic-backups-${protectedRepository}-check.service"
      "restic-backups-${protectedRepository}-prune.service"
      "restic-restore-drill-${protectedRepository}.service"
    ];

  systemdStatusScript = pkgs.writeShellScript "psi-systemd-status" ''
    exec ${pkgs.python3}/bin/python3 - <<'PY'
    import json
    import subprocess
    import time

    HOST = "psi"
    UNITS = ${builtins.toJSON monitoredSystemdUnits}
    MAX_SUCCESS_AGE_SECONDS = 45 * 24 * 3600
    SERVICE_PROPERTIES = [
        "Description",
        "LoadState",
        "ActiveState",
        "SubState",
        "Result",
        "ExecMainStatus",
        "ExecMainStartTimestamp",
        "ExecMainExitTimestamp",
        "NRestarts",
    ]
    TIMER_PROPERTIES = [
        "LoadState",
        "ActiveState",
        "LastTriggerUSec",
        "NextElapseUSecRealtime",
        "Result",
    ]

    now = int(time.time())

    def systemctl_show(unit, properties):
        command = ["${pkgs.systemd}/bin/systemctl", "show", "--timestamp=unix", unit]
        command += [argument for prop in properties for argument in ("--property", prop)]
        result = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)

    def unix_timestamp(value):
        if value in ("", "0", "n/a"):
            return None
        try:
            return int(float(value.removeprefix("@")))
        except ValueError:
            return None

    def age_seconds(value):
        timestamp = unix_timestamp(value)
        return None if timestamp is None else max(0, now - timestamp)

    def seconds_until(value):
        timestamp = unix_timestamp(value)
        return None if timestamp is None else timestamp - now

    def health(result, exit_status, last_success_age):
        if result not in ("", "success") or exit_status not in ("", "0"):
            return "FAIL", "failed"
        if last_success_age is None:
            return "WARN", "never_succeeded"
        if last_success_age > MAX_SUCCESS_AGE_SECONDS:
            return "WARN", "stale_success"
        return "OK", "ok"

    def unit_snapshot(unit):
        service = systemctl_show(unit, SERVICE_PROPERTIES)
        timer = systemctl_show(unit.replace(".service", ".timer"), TIMER_PROPERTIES)
        result = service.get("Result", "")
        exit_status = service.get("ExecMainStatus", "")
        last_exit_age = age_seconds(service.get("ExecMainExitTimestamp", ""))
        last_success_age = last_exit_age if result == "success" and exit_status in ("", "0") else None
        health_status, health_reason = health(result, exit_status, last_success_age)

        event = {
            "host": HOST,
            "log_type": "systemd_status",
            "event": "job_snapshot",
            "unit": unit,
            "description": service.get("Description", ""),
            "load_state": service.get("LoadState", ""),
            "active_state": service.get("ActiveState", ""),
            "sub_state": service.get("SubState", ""),
            "result": result,
            "last_exit_status": exit_status,
            "restart_count": service.get("NRestarts", ""),
            "timer_load_state": timer.get("LoadState", ""),
            "timer_active_state": timer.get("ActiveState", ""),
            "timer_result": timer.get("Result", ""),
            "last_start_age_seconds": age_seconds(service.get("ExecMainStartTimestamp", "")),
            "last_exit_age_seconds": last_exit_age,
            "last_trigger_age_seconds": age_seconds(timer.get("LastTriggerUSec", "")),
            "last_success_age_seconds": last_success_age,
            "next_due_seconds": seconds_until(timer.get("NextElapseUSecRealtime", "")),
            "max_success_age_seconds": MAX_SUCCESS_AGE_SECONDS,
            "health": health_status,
            "health_reason": health_reason,
        }
        event["message"] = (
            f"{unit}: {event['health']} ({event['health_reason']}) "
            f"{event['active_state']}/{event['sub_state']} result={event['result']} "
            f"exit={event['last_exit_status']} last_success_age={event['last_success_age_seconds']}"
        )
        return event

    for unit in UNITS:
        print(json.dumps(unit_snapshot(unit), sort_keys=True))
    PY
  '';
in
{
  imports = [
    ../modules/disko/xfs-root.nix
    ../modules/disko/xfs-mdadm.nix
    ../modules/disko/xfs-project-quota.nix
    ../modules/nvidia.nix
    ../modules/tailscale
    ../modules/buildbot/database.nix
    ../modules/buildbot/master.nix
    ../modules/buildbot/reverse-proxy.nix
    ../modules/monitoring/vector
    ../modules/harmonia
    ../modules/multievolve
    # ../modules/vllm
    ../modules/db-sync/databases.nix
    ../modules/docling
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y404280K";

  disko.xfsMdadm = {
    enable = true;
    arrays = {
      # SSD RAID0 for workspace (16TB total)
      workspace = {
        disks.ssd1 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA05025J";
        disks.ssd2 = "/dev/disk/by-id/nvme-Samsung_SSD_9100_PRO_8TB_S7YHNJ0YA02750H";
        mountpoint = "/workspace";
        extraXfsOptions = [
          "allocsize=16m"
        ];
      };
      # HDD RAID0 for data (60TB total)
      data = {
        disks.hdd1 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0HG8X";
        disks.hdd2 = "/dev/disk/by-id/ata-ST30000NT011-3V2103_K1S0H1A7";
        mountpoint = "/data";
        extraXfsOptions = [
          "largeio"
          "allocsize=64m"
          "filestreams"
        ];
      };
    };
  };

  disko.xfsProjectQuotas = {
    enable = true;
    filesystems."/".projects.blobs = {
      id = 1001;
      path = "/blobs";
      blockHardLimit = "200g";
    };
  };

  # Enable periodic TRIM for SSD health
  services.fstrim.enable = true;

  # Use localhost for harmonia cache instead of wireguard IP
  nix.settings.substituters = lib.mkForce [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "http://127.0.0.1:5000"
  ];

  networking.hostName = "psi";

  sops.secrets = {
    ${psiProtected.secretNames.writer}.sopsFile = sharedBackupSecretsFile;
    ${psiProtected.secretNames.reader}.sopsFile = sharedBackupSecretsFile;
    ${psiProtected.secretNames.pruner}.sopsFile = sharedBackupSecretsFile;
    ${psiProtected.secretNames.repositoryPassword} = { };
  };

  sops.templates.${resticEnvTemplateName "writer"} = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.writer}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.writer}}
      AWS_DEFAULT_REGION=us-east-1
    '';
  };
  sops.templates.${resticEnvTemplateName "reader"} = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.reader}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.reader}}
      AWS_DEFAULT_REGION=us-east-1
    '';
  };
  sops.templates.${resticEnvTemplateName "pruner"} = {
    owner = "root";
    group = "root";
    mode = "0400";
    content = ''
      AWS_ACCESS_KEY_ID=${psiProtected.accessKeys.pruner}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.${psiProtected.secretNames.pruner}}
      AWS_DEFAULT_REGION=us-east-1
    '';
  };

  systemd.tmpfiles.rules = [
    "f /project/.rustic-backup-sentinel 0644 root root - -"
    "w /project/.rustic-backup-sentinel - - - - psi protected backup sentinel"
    "d /var/lib/restic-restore 0755 root root - -"
  ];

  services.restic.backups = {
    ${protectedRepository} = {
      repository = resticRepository;
      passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.${resticEnvTemplateName "writer"}.path;
      paths = [
        "/project"
        "/blobs"
      ];
      initialize = true;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    "${protectedRepository}-check" = {
      repository = resticRepository;
      passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
      timerConfig = {
        OnCalendar = "monthly";
        Persistent = true;
      };
      runCheck = true;
      checkOpts = [ "--no-lock" ];
      createWrapper = false;
    };

    "${protectedRepository}-prune" = {
      repository = resticRepository;
      passwordFile = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
      environmentFile = config.sops.templates.${resticEnvTemplateName "pruner"}.path;
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      createWrapper = false;
    };
  };

  systemd.services."backup-guard-${protectedRepository}" = {
    description = "Guard restic backup source size: ${protectedRepository}";
    after = [ "xfs-project-quota-root.service" ];
    requires = [ "xfs-project-quota-root.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      blobs_bytes=$(${pkgs.coreutils}/bin/du -sb /blobs | ${pkgs.coreutils}/bin/cut -f1)
      if [ "$blobs_bytes" -gt ${toString blobsQuotaBytes} ]; then
        echo "/blobs exceeds protected backup budget: $blobs_bytes > ${toString blobsQuotaBytes}" >&2
        exit 1
      fi

      project_bytes=$(${pkgs.coreutils}/bin/du -sb /project | ${pkgs.coreutils}/bin/cut -f1)
      if [ "$project_bytes" -gt ${toString projectBudgetBytes} ]; then
        echo "/project exceeds protected backup budget: $project_bytes > ${toString projectBudgetBytes}" >&2
        exit 1
      fi
    '';
  };

  systemd.services."restic-backups-${protectedRepository}" = {
    after = [ "backup-guard-${protectedRepository}.service" ];
    requires = [ "backup-guard-${protectedRepository}.service" ];
  };

  systemd.services."restic-restore-drill-${protectedRepository}" = {
    description = "Restore drill for restic repository: ${protectedRepository}";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      RESTIC_REPOSITORY = resticRepository;
      RESTIC_PASSWORD_FILE = config.sops.secrets.${psiProtected.secretNames.repositoryPassword}.path;
      RESTIC_CACHE_DIR = "/var/cache/restic-restore-drill-${protectedRepository}";
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.templates.${resticEnvTemplateName "reader"}.path;
      CacheDirectory = "restic-restore-drill-${protectedRepository}";
      CacheDirectoryMode = "0700";
    };
    script = ''
      set -euo pipefail
      target=/var/lib/restic-restore/${protectedRepository}
      ${pkgs.coreutils}/bin/rm -rf "$target"
      ${pkgs.coreutils}/bin/mkdir -p "$target"
      ${pkgs.restic}/bin/restic --no-lock restore latest --target "$target" --include /project/.rustic-backup-sentinel
      ${pkgs.diffutils}/bin/cmp /project/.rustic-backup-sentinel "$target/project/.rustic-backup-sentinel"
      ${pkgs.coreutils}/bin/rm -rf "$target"
    '';
  };

  systemd.timers."restic-restore-drill-${protectedRepository}" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      Unit = "restic-restore-drill-${protectedRepository}.service";
    };
  };

  # Database sync management
  services.db-sync = {
    enable = true;
    root = "/data/databases";

    # Enable databases needed for research
    databases = dbSyncDatabases;
  };

  services.prometheus.exporters.nvidia-gpu = {
    enable = true;
    listenAddress = config.networking.sbee.currentHost.wg-admin;
    port = 9835;
    extraFlags = [ "--no-shutdown-on-error" ];
  };

  networking.firewall.interfaces."wg-admin".allowedTCPPorts = [
    9835 # nvidia-gpu exporter
  ];

  services.vector.settings = {
    sources.psi_systemd_status_source = {
      type = "exec";
      command = [ (toString systemdStatusScript) ];
      mode = "scheduled";
      scheduled.exec_interval_secs = 60;
      decoding.codec = "json";
    };

    sinks.psi_systemd_status_loki = {
      type = "loki";
      inputs = [ "psi_systemd_status_source" ];
      endpoint = "http://${config.networking.sbee.hosts.rho.wg-admin}:3100";
      encoding.codec = "json";
      labels = {
        host = "{{ host }}";
        log_type = "{{ log_type }}";
        event = "{{ event }}";
      };
      batch.timeout_secs = 10;
    };
  };

  programs.singularity = {
    enable = true;
    package = pkgs.apptainer;
  };

  system.stateVersion = "25.05";
}
