# Keeps Authentik's researchers, students and staff groups equal to the Slack
# user groups of the same role (packages/slack-group-sync). Runs beside
# Authentik so the API stays on loopback; Slack is reached over Socket Mode,
# which needs no inbound port.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.slack-group-sync;
  healthPort = 9465;
  credentials = {
    slack-bot-token = "slack-group-sync-slack-bot-token";
    slack-app-token = "slack-group-sync-slack-app-token";
    authentik-token = "slack-group-sync-authentik-token";
  };
in
{
  imports = [ ../gatus/check.nix ];

  sops.secrets = lib.mapAttrs' (
    _name: key:
    lib.nameValuePair key {
      sopsFile = ./secrets.yaml;
      restartUnits = [ "slack-group-sync.service" ];
    }
  ) credentials;

  systemd.services.slack-group-sync = {
    description = "Sync Authentik groups from Slack user groups";
    after = [
      "authentik.service"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      AUTHENTIK_URL = "http://127.0.0.1:9000";
      SOURCE_SLUG = "slack";
      SYNC_GROUPS = "researchers=sjanglab-researchers,students=sjanglab-students,staff=sjanglab-staff";
      PENDING_GROUP = "sjanglab-pending";
      PROTECTED_GROUPS = "sjanglab-admins";
      SOCKET_CONNECTIONS = "2";
      RECONCILE_TIMES = "09:00,13:00,18:00";
      TIMEZONE = "Asia/Seoul";
      HEALTH_PORT = toString healthPort;
    };
    serviceConfig = {
      ExecStart = lib.getExe package;
      DynamicUser = true;
      LoadCredential = lib.mapAttrsToList (
        name: key: "${name}:${config.sops.secrets.${key}.path}"
      ) credentials;
      Restart = "always";
      RestartSec = 30;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      # AF_UNIX for name resolution through nss and systemd-resolved.
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  # The service reports unhealthy when no reconcile succeeded recently, a
  # reconcile halted, or no Socket Mode connection is open.
  gatusCheck.push = [
    {
      name = "Slack group sync";
      group = "platform";
      url = "http://127.0.0.1:${toString healthPort}/healthz";
    }
  ];
}
