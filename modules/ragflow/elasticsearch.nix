# RAGFlow Elasticsearch (NixOS native)
#
# Replaces Docker es01 container for:
# - Declarative configuration
# - Integrated backup via borgbackup
# - systemd management
{ pkgs, ... }:
{
  services.elasticsearch = {
    enable = true;
    package = pkgs.elasticsearch7; # RAGFlow uses ES 8.x features but 7.x API compatible

    settings = {
      "cluster.name" = "ragflow";
      "discovery.type" = "single-node";
      "xpack.security.enabled" = false;

      # Disk watermarks (same as docker-compose)
      "cluster.routing.allocation.disk.watermark.low" = "5gb";
      "cluster.routing.allocation.disk.watermark.high" = "3gb";
      "cluster.routing.allocation.disk.watermark.flood_stage" = "2gb";

      # Network: localhost + RAGFlow Docker bridge
      "network.host" = [
        "127.0.0.1"
        "172.30.0.1"
      ];
      "http.port" = 9200;
    };

    extraJavaOptions = [
      "-Xms1g"
      "-Xmx1g"
    ];
  };

  # Allow ES access from RAGFlow Docker network
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 9200 ];
}
