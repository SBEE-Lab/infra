# Buildbot Master (deployed on psi)
{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  inherit (inputs.buildbot-nix.lib) interpolate;
  buildbotDomain = "buildbot.sjanglab.org";
in
{
  imports = [ inputs.buildbot-nix.nixosModules.buildbot-master ];

  services.buildbot-nix.master = {
    enable = true;
    domain = buildbotDomain;
    workersFile = config.sops.secrets.buildbot-workers.path;
    buildSystems = [ "x86_64-linux" ];
    evalWorkerCount = 8;
    evalMaxMemorySize = 8192;

    github = {
      enable = true;
      appId = 2388926;
      appSecretKeyFile = config.sops.secrets.github-app-private-key.path;
      webhookSecretFile = config.sops.secrets.github-webhook-secret.path;
      oauthId = "Ov23lixVe87HVC7XJzqn";
      oauthSecretFile = config.sops.secrets.github-oauth-secret.path;
      # topic defaults to "build-with-buildbot"
      userAllowlist = [
        "SBEE-Lab"
        "mulatta"
        "zmblr"
      ];
    };

    # Push to niks3 cache for selected projects
    postBuildSteps = [
      {
        name = "Push to niks3 cache";
        environment = {
          NIKS3_SERVER_URL = "https://niks3.mulatta.io";
        };
        command = [
          "bash"
          "-c"
          (interpolate ''
            case "%(prop:projectname)s" in
              mulatta/dots)
                echo "Pushing to niks3 cache..."
                niks3 push --auth-token "%(secret:niks3-auth-token)s" "result-%(prop:attr)s"
                ;;
              *)
                echo "Skipping niks3 push for %(prop:projectname)s"
                ;;
            esac
          '')
        ];
        warnOnly = true;
      }
    ];

    authBackend = "github";
    admins = [ "mulatta" ];
  };

  services.buildbot-master.dbUrl = lib.mkForce "postgresql://buildbot@${hosts.rho.wg-serv}/buildbot";
  services.buildbot-master.buildbotUrl = lib.mkForce "https://${buildbotDomain}/";

  systemd.services.buildbot-master.environment = {
    PGPASSFILE = config.sops.secrets.buildbot-pgpass.path;
  };

  systemd.services.buildbot-master.serviceConfig.LoadCredential = [
    "niks3-auth-token:${config.sops.secrets.niks3-auth-token.path}"
  ];

  services.buildbot-master.extraConfig = ''
    c["www"]["port"] = "tcp:8010:interface=${hosts.psi.wg-serv}"
    c["protocols"] = {"pb": {"port": "tcp:9989:interface=${hosts.psi.wg-serv}"}}
  '';

  networking.firewall.interfaces.wg-serv.allowedTCPPorts = [
    8010
    9989
  ];

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
    niks3-auth-token = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot";
    };
  };

  users.users.buildbot = {
    isSystemUser = true;
    group = "buildbot";
  };
  users.groups.buildbot = { };
}
