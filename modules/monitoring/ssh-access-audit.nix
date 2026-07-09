{
  config,
  lib,
  pkgs,
  ...
}:
let
  wgAdminAddr = config.networking.sbee.hosts.rho.wg-admin;

  hosts = lib.mapAttrs (_name: host: host.wg-admin) (
    lib.filterAttrs (_name: host: host ? wg-admin && host.wg-admin != null) config.networking.sbee.hosts
  );

  adminPeers = lib.mapAttrs' (
    device: peer:
    lib.nameValuePair peer.address {
      inherit device;
      inherit (peer) owner;
    }
  ) config.networking.sbee.adminWireguardPeers;

  inventory = pkgs.writeText "ssh-access-audit-inventory.json" (
    builtins.toJSON {
      inherit hosts;
      admin_peers = adminPeers;
      bastion_host = "eta";
      bastion_ip = config.networking.sbee.hosts.eta.wg-admin;
      emergency_lan_ranges = [ "10.80.169.38-10.80.169.40" ];
    }
  );

  python = pkgs.python313;
in
{
  users.users.ssh-access-audit = {
    isSystemUser = true;
    group = "ssh-access-audit";
    home = "/var/lib/ssh-access-audit";
  };

  users.groups.ssh-access-audit = { };

  systemd.services.ssh-access-audit = {
    description = "Correlate SSH login logs into access audit events";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "ssh-access-audit";
      Group = "ssh-access-audit";
      StateDirectory = "ssh-access-audit";
      StateDirectoryMode = "0700";
      ExecStart = lib.escapeShellArgs [
        "${python}/bin/python3"
        ./ssh-access-audit.py
        "--inventory"
        inventory
        "--loki-url"
        "http://${wgAdminAddr}:3100"
        "--state"
        "/var/lib/ssh-access-audit/seen.json"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      SystemCallFilter = [ "@system-service" ];
      MemoryMax = "256M";
    };
  };

  systemd.timers.ssh-access-audit = {
    description = "Run SSH access audit correlator every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "60s";
      OnUnitActiveSec = "60s";
      AccuracySec = "10s";
      Persistent = true;
    };
  };

  services.sbee.systemdStatusExporter.units = [
    {
      unit = "ssh-access-audit.service";
      jobClass = "audit";
      triggerKind = "timer";
      alertEnabled = true;
      maxSuccessAgeSeconds = 5 * 60;
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/ssh-access-audit 0700 ssh-access-audit ssh-access-audit - -"
  ];
}
