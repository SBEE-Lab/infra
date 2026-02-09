# vLLM model serving with AWQ quantization
#
# Serves LLM via OpenAI-compatible API.
# Embedding/Rerank handled by TEI (more efficient).
# Requires CUDA support (import nvidia.nix in host config).
{
  lib,
  pkgs,
  ...
}:
let
  domain = "vllm.sjanglab.org";
  dataDir = "/workspace/vllm";
  modelDir = "${dataDir}/models";

  # vLLM package (CUDA enabled via pkgsCuda in configurations.nix)
  inherit (pkgs.python3Packages) vllm;

  # Model configurations (A6000 48GB)
  # Qwen3-32B-AWQ (~17GB) + KV cache
  # Embedding/Rerank: TEI handles via nginx routing
  # Note: enforce-eager disables CUDA graphs to avoid OOM during warmup
  models = {
    chat = {
      model = "Qwen/Qwen3-32B-AWQ";
      port = 8100;
      extraArgs = [
        "--quantization"
        "awq"
        "--max-model-len"
        "32768"
        "--gpu-memory-utilization"
        "0.80" # Leave ~10GB for TEI embed/rerank
        "--enforce-eager" # Skip CUDA graph capture to avoid OOM
      ];
    };
  };

  mkVllmService = name: cfg: {
    description = "vLLM ${name} server (${cfg.model})";
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
      User = "vllm";
      Group = "vllm";
      WorkingDirectory = dataDir;
      ExecStart = lib.concatStringsSep " " (
        [
          "${vllm}/bin/vllm"
          "serve"
          cfg.model
          "--host"
          "127.0.0.1"
          "--port"
          (toString cfg.port)
          "--download-dir"
          modelDir
          "--dtype"
          "auto"
        ]
        ++ cfg.extraArgs
      );
      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "30min"; # Model download can take time

      # CUDA access overrides (same as ollama)
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
      name = "vLLM";
      group = "ai";
      url = "http://127.0.0.1:8100/health";
    }
  ];

  # Generate systemd services for each model
  systemd.services = lib.mapAttrs' (
    name: cfg: lib.nameValuePair "vllm-${name}" (mkVllmService name cfg)
  ) models;

  # User/group
  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = dataDir;
  };
  users.groups.vllm = { };

  # Directories
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 vllm vllm -"
    "d ${modelDir} 0755 vllm vllm -"
  ];

  # ACME certificate receiver
  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-vllm";
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

      # Embedding API -> TEI (port 8201, more efficient for embeddings)
      locations."/v1/embeddings" = {
        proxyPass = "http://127.0.0.1:8201";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
          client_max_body_size 10M;
        '';
      };

      # Rerank API -> TEI (port 8202)
      # Rewrite /v1/score to /rerank for TEI compatibility
      locations."/v1/score" = {
        proxyPass = "http://127.0.0.1:8202/rerank";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
          client_max_body_size 10M;
        '';
      };

      # Chat API + default -> port 8100
      locations."/" = {
        proxyPass = "http://127.0.0.1:8100";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          client_max_body_size 100M;
        '';
      };
    };
  };

  # Firewall: Tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
