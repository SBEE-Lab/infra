# Nixbot CI service (deployed on psi)
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  nixbotDomain = "nixbot.sjanglab.org";
in
{
  imports = [
    inputs.nixbot.nixosModules.nixbot
    ./niks3-routes.nix
  ];

  services.nixbot = {
    enable = true;
    domain = nixbotDomain;
    # Public traffic terminates on eta first, then reaches psi's nginx over
    # wg-admin. Generate external URLs with the public HTTPS scheme.
    useHTTPS = true;

    buildSystems = [ "x86_64-linux" ];
    evalWorkerCount = 8;
    evalMaxMemorySize = 8192;
    buildConcurrency = 48;

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

    niks3 = {
      enable = true;
      package = inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.default;
      routes = {
        mulatta = {
          projectPatterns = [ "mulatta/*" ];
          serverUrl = "https://niks3.mulatta.io";
          authTokenFile = config.sops.secrets.niks3-mulatta-auth-token.path;
        };
        sjanglab = {
          default = true;
          serverUrl = "https://niks3.sjanglab.org";
          authTokenFile = config.sops.secrets.niks3-sjanglab-auth-token.path;
        };
      };
    };
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
    niks3-mulatta-auth-token = {
      sopsFile = ./secrets.yaml;
      owner = "nixbot";
    };
    # PID 1 copies this secret into nixbot's credential directory, while the
    # sjanglab niks3 service reads the source file directly.
    niks3-sjanglab-auth-token = {
      sopsFile = ./secrets.yaml;
      owner = "niks3";
    };
  };
}
