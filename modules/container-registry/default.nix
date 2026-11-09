{
  config,
  ...
}:
let
  domain = "registry.sjanglab.org";
  secretsFile = ./secrets.yaml;
  pushBot = "docker-push-bot";
  admin = "registry-admin";
  credential = name: "/run/credentials/zot.service/${name}";
  # CI overwrites the <image>-cache:buildkit tag on every build.
  pushActions = [
    "read"
    "create"
    "update"
  ];
in
{
  imports = [
    ../zot
    ./reverse-proxy.nix
  ];

  services.zot = {
    enable = true;
    credentials = {
      htpasswd = config.sops.templates.zot-htpasswd.path;
      "oidc.json" = config.sops.templates.zot-oidc.path;
      "session-keys.json" = config.sops.templates.zot-session-keys.path;
    };
    settings = {
      distSpecVersion = "1.1.1";
      storage = {
        # Blobs, the dedupe index and metaDB live on the HDD array; images are
        # reproducible, so the store is not backed up.
        rootDirectory = "/data/zot";
        dedupe = true;
        gc = true;
      };
      http = {
        address = "127.0.0.1";
        port = "5000";
        realm = domain;
        # OIDC redirect URIs are built from this rather than the proxied Host.
        externalUrl = "https://${domain}";
        # The 60s defaults cover a whole request body, so a single-PATCH
        # multi-GB layer push fails; match nginx's 1800s proxy timeouts.
        readTimeout = "30m";
        writeTimeout = "30m";
        # Accept Docker media types so default docker/skopeo pushes and Docker
        # Hub mirrors work; zot stores them as-is without converting to OCI.
        compat = [ "docker2s2" ];
        auth = {
          htpasswd.path = credential "htpasswd";
          # Every registry request carries Basic credentials, so nginx cannot
          # rate-limit login attempts separately; slow failures down instead.
          failDelay = 5;
          # Lab members sign in to the UI through authentik; docker and skopeo
          # cannot run OIDC, so they log in with an API key created in the UI.
          # A key keeps the groups from its owner's last UI login, so removing
          # someone in authentik does not revoke keys they already hold.
          openid.providers.oidc = {
            name = "authentik";
            issuer = "https://auth.sjanglab.org/application/o/registry/";
            credentialsFile = credential "oidc.json";
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            claimMapping.username = "preferred_username";
          };
          apikey = true;
          # Fixed keys keep UI sessions valid across zot restarts.
          sessionKeysFile = credential "session-keys.json";
        };
        # Only research/ and infra/ exist for non-admins; any other repository
        # matches no pattern and is denied. zot applies the single longest
        # matching pattern, so a more specific pattern must restate every
        # policy it should keep.
        accessControl = {
          repositories = {
            "research/**".policies = [
              {
                users = [ pushBot ];
                actions = pushActions;
              }
              {
                # Without update a published tag cannot be overwritten.
                groups = [ "sjanglab-researchers" ];
                actions = [
                  "read"
                  "create"
                ];
              }
              {
                groups = [ "sjanglab-students" ];
                actions = [ "read" ];
              }
            ];
            "infra/**".policies = [
              {
                users = [ pushBot ];
                actions = pushActions;
              }
            ];
          };
          adminPolicy = {
            users = [ admin ];
            groups = [ "sjanglab-admins" ];
            actions = pushActions ++ [ "delete" ];
          };
        };
      };
      extensions = {
        search = {
          enable = true;
          # Trivy scans blobs from local storage. Each update pulls trivy-db and
          # the much larger trivy-java-db from ghcr.io, which zot cannot skip,
          # so refresh daily instead of every 2h.
          cve.updateInterval = "24h";
        };
        ui.enable = true;
      };
      log.level = "info";
    };
  };

  sops.secrets = {
    container-registry-docker-push-bot-password-hash.sopsFile = secretsFile;
    container-registry-admin-password-hash.sopsFile = secretsFile;
    container-registry-oidc-client-secret.sopsFile = secretsFile;
    container-registry-session-hash-key.sopsFile = secretsFile;
    container-registry-session-encrypt-key.sopsFile = secretsFile;
  };

  # LoadCredential copies the file at start, so account changes need a restart.
  sops.templates.zot-htpasswd = {
    restartUnits = [ "zot.service" ];
    content = ''
      ${pushBot}:${config.sops.placeholder."container-registry-docker-push-bot-password-hash"}
      ${admin}:${config.sops.placeholder."container-registry-admin-password-hash"}
    '';
  };

  sops.templates.zot-oidc = {
    restartUnits = [ "zot.service" ];
    content = builtins.toJSON {
      clientid = "registry";
      clientsecret = config.sops.placeholder."container-registry-oidc-client-secret";
    };
  };

  sops.templates.zot-session-keys = {
    restartUnits = [ "zot.service" ];
    content = builtins.toJSON {
      hashKey = config.sops.placeholder."container-registry-session-hash-key";
      encryptKey = config.sops.placeholder."container-registry-session-encrypt-key";
    };
  };
}
