# vLLM behind llama-swap: started on demand, stopped after `ttl` to free the GPU.
# Upstream image because nixpkgs vLLM lags new model support.
{
  config,
  lib,
  ...
}:
let
  port = 8100;
  hfCache = "/workspace/shared/huggingface";

  docker = lib.getExe config.virtualisation.docker.package;
  container = "vllm";
in
{
  imports = [ ../gatus/check.nix ];

  gatusCheck.push = [
    {
      name = "vLLM";
      group = "ai";
      systemdService = "llama-swap.service";
    }
  ];

  services.llama-swap = {
    enable = true;
    # Wildcard avoids coupling startup to Naru address readiness.
    listenAddress = "[::]";
    # `llama-swap -validate` fails on the unset ${env.*} secret in the build sandbox.
    validateConfigFile = false;
    inherit port;
    settings = {
      apiKeys = [ "\${env.LLAMA_SWAP_API_KEY}" ];
      healthCheckTimeout = 3600;
      models."qwen3.6-35b-a3b" = {
        cmd = lib.escapeShellArgs [
          docker
          "run"
          "--rm"
          "--name"
          container
          "--device=nvidia.com/gpu=all"
          "--ipc=host"
          "--publish"
          "127.0.0.1:\${PORT}:8000"
          "--volume"
          "${hfCache}:/root/.cache/huggingface"
          "vllm/vllm-openai:v0.32.0@sha256:befccf0e7e4089aa23926bb6f887a85c0d46c2a99e6de5c5ffdf5cb7957c5b34"
          "--model"
          "Qwen/Qwen3.6-35B-A3B-FP8"
          "--served-model-name"
          "qwen3.6-35b-a3b"
          "--max-model-len"
          "262144"
          "--kv-cache-dtype"
          "fp8"
          "--gpu-memory-utilization"
          "0.95"
          "--limit-mm-per-prompt"
          ''{"image":4,"video":0}''
          "--reasoning-parser"
          "qwen3"
          "--default-chat-template-kwargs"
          ''{"enable_thinking":false}''
          "--enable-auto-tool-choice"
          "--tool-call-parser"
          "qwen3_coder"
          "--enable-force-include-usage"
          "--enable-prompt-tokens-details"
          "--disable-uvicorn-access-log"
        ];
        # Otherwise only the docker client is killed and the container keeps the GPU.
        cmdStop = "${docker} stop ${container}";
        ttl = 600;
        concurrencyLimit = 64;
      };
    };
  };

  systemd.services.llama-swap = {
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    # nvidia-smi feeds the web UI's GPU panel.
    path = [ config.hardware.nvidia.package.bin ];
    serviceConfig = {
      ExecStartPre = "-${docker} rm --force ${container}";
      ExecStopPost = "-${docker} rm --force ${container}";
      DynamicUser = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      User = "llama-swap";
      Group = "llama-swap";
      SupplementaryGroups = [ "docker" ];
      EnvironmentFile = config.sops.templates.llama-swap-env.path;
    };
  };

  sops.secrets.llama-swap-api-key = { };
  sops.templates.llama-swap-env = {
    content = ''
      LLAMA_SWAP_API_KEY=${config.sops.placeholder.llama-swap-api-key}
    '';
    restartUnits = [ "llama-swap.service" ];
  };

  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
  };
  users.groups.llama-swap = { };

  systemd.tmpfiles.rules = [ "d ${hfCache} 0755 root root -" ];

  # Naru only spans our own hosts and already encrypts and authenticates.
  networking.firewall.interfaces."tinc.naru".allowedTCPPorts = [ port ];
}
