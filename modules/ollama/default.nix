{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  port = 11434;
  domain = "ollama.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";
  authentikOutpost = "http://${hosts.eta.wg-admin}:9000";
in
{
  imports = [ ../acme/sync.nix ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-ollama";
    }
  ];
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "127.0.0.1"; # Only listen locally, nginx handles external
    inherit port;
    models = "/workspace/ollama/models";
    home = "/workspace/ollama";
    # Explicit user/group to disable DynamicUser (needed for /workspace access)
    user = "ollama";
    group = "ollama";
    environmentVariables = {
      # Note: CUDA_VISIBLE_DEVICES="all" breaks GPU detection, leave unset
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_KEEP_ALIVE = "5m";
      # Allow requests from nginx proxy
      OLLAMA_ORIGINS = "https://ollama.sjanglab.org,https://*.sjanglab.org";
      # CUDA libraries (wrapper doesn't propagate properly in systemd)
      LD_LIBRARY_PATH = lib.concatStringsSep ":" [
        "${pkgs.ollama-cuda}/lib/ollama"
        "/run/opengl-driver/lib"
        "${pkgs.cudaPackages.cuda_cudart}/lib"
        "${pkgs.cudaPackages.libcublas}/lib"
      ];
    };
    # Managed models - automatically downloaded and synced
    loadModels = [
      "qwen2.5-72b"
      "llama3.3-70b"
      "openbiollm-70b"
      "biomistral"
      "bge-m3"
    ];
    syncModels = true;
  };

  # Create ollama user/group for /workspace access
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    home = "/workspace/ollama";
  };
  users.groups.ollama = { };

  # Minimal overrides for CUDA GPU access
  # NixOS ollama module sets hardening defaults that break CUDA
  systemd.services.ollama.serviceConfig = {
    # Required: module always sets DynamicUser=true, need false for /workspace
    DynamicUser = lib.mkForce false;
    # Required: CUDA JIT compilation needs executable memory
    MemoryDenyWriteExecute = lib.mkForce false;
    # Required: UID mapping breaks /dev/nvidia* access
    PrivateUsers = lib.mkForce false;
    # Required: module sets "closed", need "auto" for GPU devices
    DevicePolicy = lib.mkForce "auto";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      # Authentik outpost - auth endpoint (internal, for auth_request)
      locations."/outpost.goauthentik.io/auth/nginx" = {
        proxyPass = "${authentikOutpost}/outpost.goauthentik.io/auth/nginx";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header Authorization $http_authorization;
        '';
      };

      # Authentik outpost - start/callback (external, for redirects)
      locations."/outpost.goauthentik.io" = {
        proxyPass = "${authentikOutpost}/outpost.goauthentik.io";
        extraConfig = ''
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header Authorization $http_authorization;
        '';
      };

      # Signin redirect - same domain, not auth.sjanglab.org
      locations."@authentik_signin" = {
        extraConfig = ''
          internal;
          return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
        '';
      };

      # Main location - protected by Authentik forward auth
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        recommendedProxySettings = false; # Override Host header manually
        extraConfig = ''
          # Authentik forward auth
          auth_request /outpost.goauthentik.io/auth/nginx;
          auth_request_set $authentik_email $upstream_http_x_authentik_email;
          error_page 401 = @authentik_signin;
          proxy_set_header X-authentik-email $authentik_email;

          # Override Host header for ollama
          proxy_set_header Host 127.0.0.1:${toString port};
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # Ollama streaming responses
          proxy_buffering off;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;

          # Large model responses
          client_max_body_size 100M;
        '';
      };
    };
  };

  # Firewall: HTTPS for Tailscale only
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];

  # Ensure directories exist on /workspace (SSD RAID0)
  systemd.tmpfiles.rules = [
    "d /workspace/ollama 0755 ollama ollama -"
    "d /workspace/ollama/models 0755 ollama ollama -"
  ];
}
