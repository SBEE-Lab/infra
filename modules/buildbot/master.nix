# Nixbot CI service (deployed on psi)
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs.nixbot.lib) interpolate;
  buildbotDomain = "buildbot.sjanglab.org";
in
{
  imports = [ inputs.nixbot.nixosModules.nixbot ];

  services.nixbot = {
    enable = true;
    domain = buildbotDomain;
    # Public traffic terminates on eta first, then reaches psi's nginx over
    # wg-admin. Generate external URLs with the public HTTPS scheme.
    useHTTPS = true;

    buildSystems = [ "x86_64-linux" ];
    evalWorkerCount = 8;
    evalMaxMemorySize = 8192;
    buildConcurrency = 8;

    # Keep buildbot-era check names so existing branch protection rules match.
    statusContextPrefix = "buildbot";

    github = {
      enable = true;
      appId = 2388926;
      appSecretKeyFile = config.sops.secrets.github-app-private-key.path;
      webhookSecretFile = config.sops.secrets.github-webhook-secret.path;
      oauthId = "Iv23liVojH0Fo2OIQ24f";
      oauthSecretFile = config.sops.secrets.github-oauth-secret.path;
      topic = "build-with-buildbot";
      userAllowlist = [
        "SBEE-Lab"
        "mulatta"
      ];
    };

    admins = [ "github:mulatta" ];

    outputsPath = "/var/www/buildbot/nix-outputs/";

    postBuildSteps = [
      {
        name = "Push selected repositories to niks3 cache";
        environment = {
          NIKS3_SERVER_URL = "https://niks3.mulatta.io";
        };
        command = [
          "bash"
          "-c"
          (interpolate ''
            set -euo pipefail

            case "%(prop:project)s" in
              mulatta/dots|mulatta/seqtable)
                echo "Pushing %(prop:project)s:%(prop:attr)s to niks3 cache..."
                export NIKS3_AUTH_TOKEN_FILE="$CREDENTIALS_DIRECTORY/niks3-auth-token"
                niks3 push "%(prop:out_link)s"
                ;;
              *)
                echo "Skipping niks3 push for %(prop:project)s"
                ;;
            esac
          '')
        ];
        warnOnly = true;
      }
    ];
  };

  systemd.services.nixbot = {
    path = [ inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.default ];
    serviceConfig.LoadCredential = [
      "niks3-auth-token:${config.sops.secrets.niks3-auth-token.path}"
    ];
  };

  sops.secrets = {
    github-app-private-key = {
      sopsFile = ./secrets.yaml;
      owner = "nixbot";
      mode = "0400";
    };
    github-webhook-secret = {
      sopsFile = ./secrets.yaml;
      owner = "nixbot";
    };
    github-oauth-secret = {
      sopsFile = ./secrets.yaml;
      owner = "nixbot";
    };
    niks3-auth-token = {
      sopsFile = ./secrets.yaml;
      owner = "nixbot";
    };
  };
}
