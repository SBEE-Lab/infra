{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 11434;
  domain = "ollama.sjanglab.org";
  certDir = "/var/lib/acme/${domain}";

  # Public key for acme-sync from eta
  acmeSyncPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7mZ/UfOMpnrHaIigljsGWXCQAovWezdPpA3WQy1Qgu acme-sync@eta";
in
{
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
      CUDA_VISIBLE_DEVICES = "all";
      OLLAMA_NUM_PARALLEL = "2";
      OLLAMA_KEEP_ALIVE = "5m";
      # Allow requests from nginx proxy
      OLLAMA_ORIGINS = "https://ollama.sjanglab.org,https://*.sjanglab.org";
    };
  };

  # Create ollama user/group for /workspace access
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    home = "/workspace/ollama";
  };
  users.groups.ollama = { };

  # Disable DynamicUser to allow /workspace access with static user
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;

  # acme-sync user for receiving certificates from eta
  users.users.acme-sync-ollama = {
    isSystemUser = true;
    group = "acme-sync-ollama";
    home = certDir;
    shell = "/run/current-system/sw/bin/bash";
    openssh.authorizedKeys.keys = [ acmeSyncPubKey ];
  };
  users.groups.acme-sync-ollama.members = [ "nginx" ];

  # Reload nginx when certificates are updated
  systemd.services.acme-sync-ollama-reload-nginx = {
    description = "Reload nginx after ollama certificate sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/bin/systemctl reload nginx";
    };
  };
  systemd.paths.acme-sync-ollama-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "${certDir}/fullchain.pem";
      Unit = "acme-sync-ollama-reload-nginx.service";
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        recommendedProxySettings = false; # Override Host header manually
        extraConfig = ''
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
    "d ${certDir} 0750 acme-sync-ollama acme-sync-ollama - -"
  ];
}
