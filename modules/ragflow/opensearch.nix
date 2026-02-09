# RAGFlow OpenSearch (NixOS native)
#
# Using OpenSearch as ES-compatible document store
# RAGFlow requires ES 8+ or OpenSearch
_: {
  services.opensearch = {
    enable = true;
    settings = {
      "cluster.name" = "ragflow";
      "discovery.type" = "single-node";
      "network.host" = "0.0.0.0";
      "http.port" = 9200;
      # Disable security for internal use
      "plugins.security.disabled" = true;
    };

    extraJavaOptions = [
      "-Xms1g"
      "-Xmx1g"
    ];
  };

  # Allow access from RAGFlow Docker network only
  networking.firewall.interfaces.br-ragflow.allowedTCPPorts = [ 9200 ];
}
