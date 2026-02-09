# RAGFlow Redis (NixOS native)
#
# Replaces Docker redis container for:
# - Declarative configuration
# - systemd management
{ lib, pkgs, ... }:
let
  dataDir = "/var/lib/ragflow";
in
{
  # Use Valkey as Redis-compatible server (global package)
  services.redis.package = pkgs.valkey;

  services.redis.servers.ragflow = {
    enable = true;
    bind = "127.0.0.1";
    port = 6379;

    settings = {
      maxmemory = "256mb";
      maxmemory-policy = "allkeys-lru";
    };
  };

  # Set password dynamically from ragflow-env
  systemd.services.redis-ragflow.postStart =
    let
      redisCli = "${pkgs.valkey}/bin/valkey-cli";
      envFile = "${dataDir}/.env";
    in
    lib.mkAfter ''
      if [ -f "${envFile}" ]; then
        REDIS_PW=$(grep '^REDIS_PASSWORD=' "${envFile}" | cut -d= -f2-)
        ${redisCli} -p 6379 CONFIG SET requirepass "$REDIS_PW" || true
      fi
    '';

  # Allow Redis access from RAGFlow Docker network
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 6379 ];
}
