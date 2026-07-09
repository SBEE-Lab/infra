# Text Embeddings Inference (TEI) service for embedding/reranking models.
{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tei;
  domain = "tei.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;

  modelType = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable this TEI model service.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        description = "Hugging Face model id.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        description = "TCP port for this TEI model service.";
      };

      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed to text-embeddings-router.";
      };
    };
  };

  enabledModels = lib.filterAttrs (_: model: model.enable) cfg.models;

  mkTeiService = name: model: {
    description = "TEI ${name} server (${model.model})";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HF_HOME = cfg.modelDir;
      CUDA_VISIBLE_DEVICES = cfg.cudaVisibleDevices;
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "/run/opengl-driver/lib"
        "${pkgs.cudaPackages.cuda_cudart}/lib"
        "${pkgs.cudaPackages.libcublas}/lib"
      ];
    };

    serviceConfig = {
      Type = "simple";
      User = cfg.user;
      Group = cfg.group;
      WorkingDirectory = cfg.dataDir;
      ExecStart = lib.escapeShellArgs (
        [
          (lib.getExe cfg.package)
          "--model-id"
          model.model
          "--hostname"
          cfg.listenAddress
          "--port"
          (toString model.port)
        ]
        ++ model.extraArgs
      );
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "30min";

      DynamicUser = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
    };
  };
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  options.services.tei = {
    enable = lib.mkEnableOption "Text Embeddings Inference embedding and reranking services";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.text-embeddings-inference-cuda;
      defaultText = "self.packages.\${pkgs.stdenv.hostPlatform.system}.text-embeddings-inference-cuda";
      description = "TEI package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = config.networking.sbee.currentHost.wg-admin;
      defaultText = "config.networking.sbee.currentHost.wg-admin";
      description = "Address TEI model services bind to.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open model service ports on the configured firewall interface.";
    };

    firewallInterface = lib.mkOption {
      type = lib.types.str;
      default = "wg-admin";
      description = "Firewall interface where TEI model service ports are allowed.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/workspace/tei";
      description = "TEI state directory.";
    };

    modelDir = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.dataDir}/models";
      defaultText = ''"\${config.services.tei.dataDir}/models"'';
      description = "Hugging Face model cache directory.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "tei";
      description = "User account that runs TEI.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "tei";
      description = "Group account that runs TEI.";
    };

    cudaVisibleDevices = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = "CUDA_VISIBLE_DEVICES value for TEI.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      description = "TEI model services to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = builtins.length (builtins.attrNames enabledModels) > 0;
        message = "services.tei.models must define at least one enabled model.";
      }
    ];

    gatusCheck.push = [
      {
        name = "TEI";
        group = "ai";
        checks =
          (map (model: {
            url = "http://${cfg.listenAddress}:${toString model.port}/health";
          }) (builtins.attrValues enabledModels))
          ++ [
            { url = "https://${domain}/health/embed"; }
            { url = "https://${domain}/health/rerank"; }
          ];
      }
    ];

    acmeSyncer.mkReceiver = [
      { inherit domain; }
    ];

    services.nginx = {
      enable = true;
      virtualHosts.${domain} = {
        forceSSL = true;
        sslCertificate = "${certDir}/fullchain.pem";
        sslCertificateKey = "${certDir}/key.pem";
        extraConfig = ''
          access_log /var/log/nginx/access-audit/tei.log nginx_access_json;
        '';

        locations."/embed/" = {
          proxyPass = "http://127.0.0.1:8201/";
          extraConfig = ''
            client_max_body_size 100M;
            proxy_read_timeout 300s;
          '';
        };
        locations."/rerank/" = {
          proxyPass = "http://127.0.0.1:8202/";
          extraConfig = ''
            client_max_body_size 100M;
            proxy_read_timeout 300s;
          '';
        };
        locations."= /health/embed".proxyPass = "http://127.0.0.1:8201/health";
        locations."= /health/rerank".proxyPass = "http://127.0.0.1:8202/health";
      };

      virtualHosts.tei-embed-metrics = {
        serverName = "tei-embed-metrics.internal";
        listen = [
          {
            addr = wgAdminAddr;
            port = 9201;
          }
        ];
        locations."= /metrics" = {
          proxyPass = "http://127.0.0.1:8201/metrics";
          extraConfig = "access_log off;";
        };
        locations."/".extraConfig = "return 403;";
      };

      virtualHosts.tei-rerank-metrics = {
        serverName = "tei-rerank-metrics.internal";
        listen = [
          {
            addr = wgAdminAddr;
            port = 9202;
          }
        ];
        locations."= /metrics" = {
          proxyPass = "http://127.0.0.1:8202/metrics";
          extraConfig = "access_log off;";
        };
        locations."/".extraConfig = "return 403;";
      };
    };

    systemd.services = lib.mapAttrs' (
      name: model: lib.nameValuePair "tei-${name}" (mkTeiService name model)
    ) enabledModels;

    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.modelDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    networking.firewall.interfaces.${cfg.firewallInterface}.allowedTCPPorts =
      lib.mkIf cfg.openFirewall
        (map (model: model.port) (builtins.attrValues enabledModels));
  };
}
