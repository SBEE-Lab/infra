{
  config,
  containerRegistry,
  lib,
  pkgs,
  self,
  ...
}:
let
  dockerAuthPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.docker-auth;

  authConfig = {
    server = {
      addr = "${containerRegistry.auth.address}:${toString containerRegistry.auth.port}";
      real_ip_header = "X-Forwarded-For";
      real_ip_pos = -1;
    };

    token = {
      inherit (containerRegistry) issuer;
      expiration = 900;
      disable_legacy_key_id = true;
      certificate = toString containerRegistry.signingCertificate;
      key = config.sops.secrets.container-registry-token-signing-key.path;
    };

    users = {
      "" = { };
      "docker-push-bot".password =
        config.sops.placeholder."container-registry-docker-push-bot-password-hash";
      "registry-admin".password = config.sops.placeholder."container-registry-admin-password-hash";
    };

    acl = [
      {
        match.account = "docker-push-bot";
        actions = [
          "pull"
          "push"
        ];
        comment = "CI may publish images but cannot delete them.";
      }
      {
        match.account = "registry-admin";
        actions = [ "*" ];
        comment = "Human administrators may manage image retention and inspect the catalog.";
      }
      {
        match = { };
        actions = [ "pull" ];
        comment = "Images are publicly readable.";
      }
    ];
  };
in
{
  users.groups.docker-auth = { };
  users.users.docker-auth = {
    isSystemUser = true;
    group = "docker-auth";
  };

  sops.secrets = {
    container-registry-token-signing-key = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-auth";
      restartUnits = [ "docker-auth.service" ];
    };
    container-registry-docker-push-bot-password-hash = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-auth";
      restartUnits = [ "docker-auth.service" ];
    };
    container-registry-admin-password-hash = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-auth";
      restartUnits = [ "docker-auth.service" ];
    };
  };

  sops.templates.docker-auth-config = {
    owner = "docker-auth";
    content = builtins.toJSON authConfig;
    restartUnits = [ "docker-auth.service" ];
  };

  systemd.services.docker-auth = {
    description = "Docker Registry token authentication server";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-install-secrets.service" ];

    serviceConfig = {
      ExecStart = "${lib.getExe dockerAuthPackage} ${config.sops.templates.docker-auth-config.path}";
      User = "docker-auth";
      Group = "docker-auth";
      Restart = "on-failure";
      RestartSec = "5s";

      CapabilityBoundingSet = "";
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";
      UMask = "0077";
    };
  };
}
