{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.services.hermes-agent;
  system = pkgs.stdenv.hostPlatform.system;
  hermesPkg = self.inputs.llm-agents.packages.${system}.hermes-agent;
  stateDir = "/var/lib/hermes";
  runtimePath = [
    hermesPkg
  ]
  ++ (with pkgs; [
    bash
    coreutils
    curl
    fd
    file
    findutils
    git
    gnugrep
    gnused
    gnutar
    gzip
    jq
    openssh
    procps
    ripgrep
    unzip
    util-linux
    which
    xz
  ]);
  runtimeEnv = {
    TZ = "Asia/Seoul";
    HOME = stateDir;
    HERMES_HOME = "${stateDir}/.hermes";
    HERMES_INFERENCE_PROVIDER = cfg.inferenceProvider;
    HERMES_INFERENCE_MODEL = cfg.inferenceModel;
    SLACK_ALLOWED_USERS = lib.concatStringsSep "," cfg.allowedSlackUsers;
  };
in
{
  imports = [ ./network.nix ];

  options.services.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent Slack gateway";

    inferenceProvider = lib.mkOption {
      type = lib.types.str;
      default = "openai-codex";
      description = "Hermes inference provider name.";
    };

    inferenceModel = lib.mkOption {
      type = lib.types.str;
      default = "gpt-5.5";
      description = "Hermes inference model name.";
    };

    allowedSlackUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Slack user IDs allowed to use Hermes.";
    };

    enableDashboard = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to run the local Hermes dashboard in the container.";
    };

    externalInterface = lib.mkOption {
      type = lib.types.str;
      description = "Host interface used for restricted Hermes egress.";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "117.16.191.6"
        "168.126.63.1"
      ];
      description = "DNS servers available to the isolated Hermes container.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.allowedSlackUsers != [ ];
        message = "services.hermes-agent.allowedSlackUsers must list at least one Slack user ID.";
      }
    ];

    sops.secrets = {
      hermes-slack-bot-token.sopsFile = ./secrets.yaml;
      hermes-slack-app-token.sopsFile = ./secrets.yaml;
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 - - -"
    ];

    containers.hermes = {
      autoStart = true;

      bindMounts.${stateDir} = {
        hostPath = stateDir;
        isReadOnly = false;
      };

      extraFlags = [
        "--load-credential=slack-bot-token:${config.sops.secrets.hermes-slack-bot-token.path}"
        "--load-credential=slack-app-token:${config.sops.secrets.hermes-slack-app-token.path}"
      ];

      config = _: {
        system.stateVersion = "25.05";

        users.users.hermes = {
          isSystemUser = true;
          group = "hermes";
          uid = 2001;
          home = stateDir;
        };
        users.groups.hermes.gid = 2001;

        time.timeZone = "Asia/Seoul";
        environment.systemPackages = [ hermesPkg ];

        systemd.tmpfiles.rules = [
          "d ${stateDir} 0750 hermes hermes -"
          "d ${stateDir}/.hermes 0750 hermes hermes -"
          # Sticky root ownership protects future Nix-owned skill symlinks while
          # still letting Hermes create and manage its own sibling skills.
          "d ${stateDir}/.hermes/skills 1770 root hermes -"
          "f ${stateDir}/.hermes/.no-bundled-skills 0640 hermes hermes -"
          "L+ ${stateDir}/.hermes/config.yaml - - - - ${./config.yml}"
        ];

        systemd.services.hermes-skill-policy = {
          description = "Apply Hermes declarative skill policy";
          wantedBy = [ "multi-user.target" ];
          before = [ "hermes.service" ] ++ lib.optional cfg.enableDashboard "hermes-dashboard.service";

          path = runtimePath;
          environment = runtimeEnv;

          serviceConfig = {
            Type = "oneshot";
            User = "hermes";
            Group = "hermes";
            WorkingDirectory = stateDir;
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "hermes-skill-policy" ''
              set -euo pipefail
              exec ${lib.getExe hermesPkg} skills opt-out --remove --yes
            '';
          };
        };

        systemd.services.hermes = {
          description = "Hermes Agent Slack gateway";
          wantedBy = [ "multi-user.target" ];
          after = [
            "hermes-skill-policy.service"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          requires = [ "hermes-skill-policy.service" ];

          path = runtimePath;
          environment = runtimeEnv;

          serviceConfig = {
            User = "hermes";
            Group = "hermes";
            WorkingDirectory = stateDir;
            StateDirectory = "hermes";
            ImportCredential = [
              "slack-bot-token"
              "slack-app-token"
            ];
            Restart = "on-failure";
            RestartSec = 30;
            ExecStart = pkgs.writeShellScript "hermes-gateway" ''
              set -euo pipefail
              SLACK_BOT_TOKEN=$(< "$CREDENTIALS_DIRECTORY/slack-bot-token")
              SLACK_APP_TOKEN=$(< "$CREDENTIALS_DIRECTORY/slack-app-token")
              export SLACK_BOT_TOKEN SLACK_APP_TOKEN
              exec ${lib.getExe hermesPkg} gateway run
            '';
          };
        };

        systemd.services.hermes-dashboard = lib.mkIf cfg.enableDashboard {
          description = "Hermes Agent web dashboard";
          wantedBy = [ "multi-user.target" ];
          after = [
            "hermes-skill-policy.service"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          requires = [ "hermes-skill-policy.service" ];

          path = runtimePath;
          environment = runtimeEnv;

          serviceConfig = {
            User = "hermes";
            Group = "hermes";
            WorkingDirectory = stateDir;
            StateDirectory = "hermes";
            Restart = "on-failure";
            RestartSec = 30;
            ExecStart = pkgs.writeShellScript "hermes-dashboard" ''
              set -euo pipefail
              exec ${lib.getExe hermesPkg} dashboard --host 127.0.0.1 --port 9119 --no-open --skip-build
            '';
          };
        };
      };
    };
  };
}
