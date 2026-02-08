# Text Embeddings Inference (TEI) module
#
# Serves embedding and reranker models via HTTP API.
# API endpoints: /embed (embeddings), /rerank (reranking)
# Requires CUDA support (import nvidia.nix in host config).
{
  lib,
  pkgs,
  ...
}:
let
  domain = "tei.sjanglab.org";
  dataDir = "/workspace/tei";
  modelDir = "${dataDir}/models";

  # TEI package (CUDA enabled via pkgsCuda in configurations.nix)
  tei = pkgs.text-embeddings-inference;

  # Model configurations
  # bge-m3: multilingual embedding model (~1.5GB)
  # bge-reranker-v2-m3: multilingual reranker (~1.5GB)
  models = {
    embed = {
      model = "BAAI/bge-m3";
      port = 8201;
      extraArgs = [
        "--pooling"
        "cls"
        "--max-batch-tokens"
        "16384"
        "--max-concurrent-requests"
        "512"
      ];
    };
    rerank = {
      model = "BAAI/bge-reranker-v2-m3";
      port = 8202;
      extraArgs = [
        "--max-batch-tokens"
        "16384"
        "--max-concurrent-requests"
        "512"
      ];
    };
  };

  mkTeiService = name: cfg: {
    description = "TEI ${name} server (${cfg.model})";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HF_HOME = modelDir;
      CUDA_VISIBLE_DEVICES = "0";
      # CUDA libraries
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "/run/opengl-driver/lib"
        "${pkgs.cudaPackages.cuda_cudart}/lib"
        "${pkgs.cudaPackages.libcublas}/lib"
      ];
    };

    serviceConfig = {
      Type = "simple";
      User = "tei";
      Group = "tei";
      WorkingDirectory = dataDir;
      ExecStart = lib.concatStringsSep " " (
        [
          "${tei}/bin/text-embeddings-router"
          "--model-id"
          cfg.model
          "--hostname"
          "127.0.0.1"
          "--port"
          (toString cfg.port)
        ]
        ++ cfg.extraArgs
      );
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "30min"; # Model download can take time

      # CUDA access overrides
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

  gatusCheck.push = [
    {
      name = "TEI";
      group = "ai";
      url = "http://127.0.0.1:8201/health";
    }
  ];

  # Generate systemd services for each model
  systemd.services = lib.mapAttrs' (
    name: cfg: lib.nameValuePair "tei-${name}" (mkTeiService name cfg)
  ) models;

  # User/group
  users.users.tei = {
    isSystemUser = true;
    group = "tei";
    home = dataDir;
  };
  users.groups.tei = { };

  # Directories
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 tei tei -"
    "d ${modelDir} 0755 tei tei -"
  ];

  # ACME certificate receiver
  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-tei";
    }
  ];

  # Nginx reverse proxy
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${domain}/key.pem";

      # Embedding API -> port 8201
      locations."/embed" = {
        proxyPass = "http://127.0.0.1:8201";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
          client_max_body_size 10M;
        '';
      };

      # OpenAI-compatible embeddings endpoint -> port 8201
      locations."/v1/embeddings" = {
        proxyPass = "http://127.0.0.1:8201";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
          client_max_body_size 10M;
        '';
      };

      # Rerank API -> port 8202
      locations."/rerank" = {
        proxyPass = "http://127.0.0.1:8202";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
          client_max_body_size 10M;
        '';
      };

      # Health check (default to embed service)
      locations."/health" = {
        proxyPass = "http://127.0.0.1:8201";
      };

      # Docs
      locations."/docs" = {
        proxyPass = "http://127.0.0.1:8201";
      };
    };
  };

  # Firewall: Tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
