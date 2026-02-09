# RAGFlow Redis (NixOS native)
#
# Replaces Docker redis container for:
# - Declarative configuration
# - systemd management
{ config, pkgs, ... }:
{
  # Use Valkey as Redis-compatible server (global package)
  services.redis.package = pkgs.valkey;

  services.redis.servers.ragflow = {
    enable = true;
    bind = "127.0.0.1 172.30.0.1"; # localhost + Docker bridge
    port = 6379;
    requirePassFile = config.sops.secrets.redis_password.path;

    settings = {
      maxmemory = "256mb";
      maxmemory-policy = "allkeys-lru";
    };
  };

  # Ensure sops secrets are available before Redis starts
  systemd.services.redis-ragflow.after = [ "sops-nix.service" ];
  systemd.services.redis-ragflow.wants = [ "sops-nix.service" ];

  # Allow Redis access from RAGFlow Docker network
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 6379 ];
}
