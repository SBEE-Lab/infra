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

  monitoredSystemdUnits = map (name: "db-sync-${name}.service") (builtins.attrNames dbSyncDatabases);

  systemdStatusScript = pkgs.writeShellScript "psi-systemd-status" ''
    exec ${pkgs.python3}/bin/python3 - <<'PY'
    import json
    import subprocess

    units = ${builtins.toJSON monitoredSystemdUnits}
    import time

    properties = [
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
    timer_properties = [
        "LoadState",
        "ActiveState",
        "LastTriggerUSec",
        "NextElapseUSecRealtime",
        "Result",
    ]

    now = int(time.time())

    def show(unit, props):
        command = ["${pkgs.systemd}/bin/systemctl", "show", "--timestamp=unix", unit]
        for prop in props:
            command.extend(["--property", prop])
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
        fields = {}
        for line in result.stdout.splitlines():
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            fields[key] = value
        return fields

    def unix_seconds(value):
        if not value or value == "n/a" or value == "0":
            return None
        if value.startswith("@"):
            value = value[1:]
        try:
            return int(float(value))
        except ValueError:
            return None

    def age(value):
        timestamp = unix_seconds(value)
        if timestamp is None:
            return None
        return max(0, now - timestamp)

    def seconds_until(value):
        timestamp = unix_seconds(value)
        if timestamp is None:
            return None
        return timestamp - now

    for unit in units:
        fields = show(unit, properties)
        timer_fields = show(unit.replace(".service", ".timer"), timer_properties)

        last_exit_status = fields.get("ExecMainStatus", "")
        result_status = fields.get("Result", "")
        last_start_age = age(fields.get("ExecMainStartTimestamp", ""))
        last_exit_age = age(fields.get("ExecMainExitTimestamp", ""))
        last_trigger_age = age(timer_fields.get("LastTriggerUSec", ""))
        next_due_seconds = seconds_until(timer_fields.get("NextElapseUSecRealtime", ""))
        last_success_age = last_exit_age if result_status == "success" and last_exit_status in ("", "0") else None

        max_success_age = 45 * 24 * 3600
        health = "OK"
        health_reason = "ok"
        if result_status not in ("", "success") or last_exit_status not in ("", "0"):
            health = "FAIL"
            health_reason = "failed"
        elif last_success_age is None:
            health = "WARN"
            health_reason = "never_succeeded"
        elif last_success_age > max_success_age:
            health = "WARN"
            health_reason = "stale_success"

        event = {
            "host": "psi",
            "log_type": "systemd_status",
            "event": "job_snapshot",
            "unit": unit,
            "description": fields.get("Description", ""),
            "load_state": fields.get("LoadState", ""),
            "active_state": fields.get("ActiveState", ""),
            "sub_state": fields.get("SubState", ""),
            "result": result_status,
            "last_exit_status": last_exit_status,
            "restart_count": fields.get("NRestarts", ""),
            "timer_load_state": timer_fields.get("LoadState", ""),
            "timer_active_state": timer_fields.get("ActiveState", ""),
            "timer_result": timer_fields.get("Result", ""),
            "last_start_age_seconds": last_start_age,
            "last_exit_age_seconds": last_exit_age,
            "last_trigger_age_seconds": last_trigger_age,
            "last_success_age_seconds": last_success_age,
            "next_due_seconds": next_due_seconds,
            "max_success_age_seconds": max_success_age,
            "health": health,
            "health_reason": health_reason,
        }
        event["message"] = (
            f"{unit}: {event['health']} ({event['health_reason']}) "
            f"{event['active_state']}/{event['sub_state']} result={event['result']} "
            f"exit={event['last_exit_status']} last_success_age={event['last_success_age_seconds']}"
        )
        print(json.dumps(event, sort_keys=True))
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
