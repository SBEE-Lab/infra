{
  config,
  lib,
  pkgs,
  ...
}:
let
  wgAdminAddr = config.networking.sbee.hosts.rho.wg-admin;
  python = pkgs.python313;
in
{
  users.users.tailnet-app-access-audit = {
    isSystemUser = true;
    group = "tailnet-app-access-audit";
    home = "/var/lib/tailnet-app-access-audit";
  };

  users.groups.tailnet-app-access-audit = { };

  systemd.services.tailnet-app-access-audit = {
    description = "Correlate tailnet app access logs into access audit events";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "tailnet-app-access-audit";
      Group = "tailnet-app-access-audit";
      StateDirectory = "tailnet-app-access-audit";
      StateDirectoryMode = "0700";
      ExecStart = lib.escapeShellArgs [
        "${python}/bin/python3"
        ./tailnet-app-access-audit.py
        "--loki-url"
        "http://${wgAdminAddr}:3100"
        "--state"
        "/var/lib/tailnet-app-access-audit/seen.json"
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

  systemd.timers.tailnet-app-access-audit = {
    description = "Run tailnet app access audit correlator every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "60s";
      OnUnitActiveSec = "60s";
      AccuracySec = "10s";
      Persistent = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/tailnet-app-access-audit 0700 tailnet-app-access-audit tailnet-app-access-audit - -"
  ];
}
