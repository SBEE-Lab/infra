{
  config,
  lib,
  ...
}:
let
  containerRegistry = {
    domain = "registry.sjanglab.org";
    issuer = "sjanglab-container-registry";
    signingCertificate = ./token-signing.crt;
    secretsFile = ./secrets.yaml;

    registry = {
      address = "127.0.0.1";
      port = 5000;
    };
    auth = {
      address = "127.0.0.1";
      port = 5001;
    };
  };

  r2Endpoint = "0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
  bucket = "container-registry";
in
{
  imports = [
    ./auth.nix
    ./edge-proxy.nix
  ];

  _module.args = { inherit containerRegistry; };

  services.dockerRegistry = {
    enable = true;
    listenAddress = containerRegistry.registry.address;
    port = containerRegistry.registry.port;
    storagePath = null;
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "*-*-* 04:30:00";

    extraConfig = {
      storage = {
        s3 = {
          region = "auto";
          regionendpoint = "https://${r2Endpoint}";
          inherit bucket;
          rootdirectory = "/registry";
          encrypt = false;
          secure = true;
          v4auth = true;
          chunksize = 5242880;
          multipartcopychunksize = 33554432;
          multipartcopymaxconcurrency = 10;
          multipartcopythresholdsize = 33554432;
        };
        redirect.disable = false;
      };

      auth.token = {
        realm = "https://${containerRegistry.domain}/auth";
        service = containerRegistry.domain;
        inherit (containerRegistry) issuer;
        rootcertbundle = toString containerRegistry.signingCertificate;
      };
    };
  };

  systemd.services.docker-registry = {
    after = [ "docker-auth.service" ];
    wants = [ "docker-auth.service" ];
    environment.OTEL_TRACES_EXPORTER = "none";
    serviceConfig = {
      EnvironmentFile = config.sops.templates.container-registry-env.path;
      DynamicUser = false;
      StateDirectory = "docker-registry";
      WorkingDirectory = lib.mkForce "/var/lib/docker-registry";
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

  # Distribution requires an offline registry during garbage collection to
  # avoid deleting layers uploaded while the mark phase is running.
  systemd.services.docker-registry-garbage-collect = {
    after = [ "docker-registry.service" ];
    environment.OTEL_TRACES_EXPORTER = "none";
    serviceConfig = {
      EnvironmentFile = config.sops.templates.container-registry-env.path;
      TimeoutStartSec = "6h";
    };
    script = lib.mkForce ''
      trap '${config.systemd.package}/bin/systemctl start docker-registry.service || true' EXIT
      ${config.systemd.package}/bin/systemctl stop docker-registry.service
      ${config.services.dockerRegistry.package}/bin/registry garbage-collect --delete-untagged ${config.services.dockerRegistry.configFile}
    '';
  };

  gatusCheck.pull = [
    {
      name = "Container Registry";
      url = "https://${containerRegistry.domain}/v2/";
      group = "storage";
      conditions = [
        "[STATUS] == 401"
        "[CERTIFICATE_EXPIRATION] > 720h"
      ];
    }
  ];

  sops.secrets = {
    container-registry-r2-access-key-id = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-registry";
    };
    container-registry-r2-secret-access-key = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-registry";
    };
    container-registry-http-secret = {
      sopsFile = containerRegistry.secretsFile;
      owner = "docker-registry";
    };
  };

  sops.templates.container-registry-env = {
    owner = "docker-registry";
    restartUnits = [ "docker-registry.service" ];
    content = ''
      REGISTRY_STORAGE_S3_ACCESSKEY=${config.sops.placeholder."container-registry-r2-access-key-id"}
      REGISTRY_STORAGE_S3_SECRETKEY=${config.sops.placeholder."container-registry-r2-secret-access-key"}
      REGISTRY_HTTP_SECRET=${config.sops.placeholder."container-registry-http-secret"}
    '';
  };
}
