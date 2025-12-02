# Buildbot Master (deployed on psi)
{
  config,
  inputs,
  lib,
  ...
}: let
  inherit (config.networking.sbee) hosts;
  buildbotDomain = "buildbot.sjanglab.org";
in {
  imports = [inputs.buildbot-nix.nixosModules.buildbot-master];

  services.buildbot-nix.master = {
    enable = true;
    domain = buildbotDomain;
    workersFile = config.sops.secrets.buildbot-workers.path;
    buildSystems = ["x86_64-linux"];
    evalWorkerCount = 8;
    evalMaxMemorySize = 8192;

    github = {
      enable = true;
      appId = 2388926;
      appSecretKeyFile = config.sops.secrets.github-app-private-key.path;
      webhookSecretFile = config.sops.secrets.github-webhook-secret.path;
      oauthId = "Ov23lixVe87HVC7XJzqn";
      oauthSecretFile = config.sops.secrets.github-oauth-secret.path;
      topic = "buildbot-sbee";
    };

    authBackend = "github";
    admins = ["mulatta"];

    postBuildSteps = [
      {
        name = "Push to Attic";
        environment = {
          ATTIC_TOKEN = {
            _type = "interpolate";
            value = "%(secret:attic-token)s";
          };
        };
        command = [
          "sh"
          "-c"
          {
            _type = "interpolate";
            value = "attic login sbee https://cache.sjanglab.org $ATTIC_TOKEN && attic push sbee:infra result-%(prop:attr)s";
          }
        ];
        warnOnly = true;
      }
      {
        name = "Deploy to hosts";
        command = [
          "colmena"
          "apply"
          "--parallel"
          "0" # unlimited parallelism for all 4 nodes
        ];
        warnOnly = true; # don't fail the build if deployment fails
      }
    ];
  };

  services.buildbot-master.dbUrl = lib.mkForce "postgresql://buildbot@${hosts.rho.wg-serv}/buildbot";
  services.buildbot-master.buildbotUrl = lib.mkForce "https://${buildbotDomain}/";

  systemd.services.buildbot-master.environment = {
    PGPASSFILE = config.sops.secrets.buildbot-pgpass.path;
  };

  services.buildbot-master.extraConfig = ''
    c["www"]["port"] = "tcp:8010:interface=${hosts.psi.wg-serv}"
    c["protocols"] = {"pb": {"port": "tcp:9989:interface=${hosts.psi.wg-serv}"}}
  '';

  networking.firewall.interfaces.wg-serv.allowedTCPPorts = [8010 9989];

  sops.secrets = {
    buildbot-workers = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
    };
    github-app-private-key = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
      mode = "0400";
    };
    github-webhook-secret = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
    };
    github-oauth-secret = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
    };
    buildbot-pgpass = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
      mode = "0400";
    };
    attic-auth-token = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
      mode = "0400";
    };
  };

  systemd.services.buildbot-master.serviceConfig.LoadCredential = [
    "attic-token:${config.sops.secrets.attic-auth-token.path}"
  ];

  users.users.buildbot = {
    isSystemUser = true;
    group = "buildbot";
  };
  users.groups.buildbot = {};
}
