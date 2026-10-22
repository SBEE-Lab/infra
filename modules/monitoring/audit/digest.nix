# Weekly audit digest for Slack #infra-audit, posted through the alert bridge.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  bridgeUrl = "https://infra-alert-bridge.sjang-bioe.workers.dev/digest";
  # Same delivery gate as Alertmanager: only active mode talks to Slack.
  enabled =
    config.services.sbee.monitoring.mode == "active" && config.sops.secrets ? alertmanager-bridge-token;
in
lib.mkIf enabled {
  systemd.services.infra-audit-digest = {
    description = "Post the weekly audit digest to Slack #infra-audit";
    after = [
      "network-online.target"
      "loki.service"
      "prometheus.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      LoadCredential = [ "bridge-token:${config.sops.secrets.alertmanager-bridge-token.path}" ];
      ExecStart = lib.escapeShellArgs [
        "${pkgs.python313}/bin/python3"
        ./digest.py
        "--bridge-url"
        bridgeUrl
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      SystemCallFilter = [ "@system-service" ];
    };
  };

  # Lands before the Friday 16:00 review.
  systemd.timers.infra-audit-digest = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Fri *-*-* 15:30:00 Asia/Seoul";
      Persistent = true;
    };
  };

  services.sbee.jobResults.extraJobs.infra-audit-digest.scheduled = true;
}
