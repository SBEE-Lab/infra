{
  config,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    attic-server
    attic-client
  ];

  services.atticd = {
    enable = true;

    environmentFile = config.sops.secrets.attic-credentials.path;

    settings = {
      listen = "[::1]:8080";

      # Chunked deduplication for storage efficiency
      chunking = {
        nar-size-threshold = 65536;
        min-size = 16384;
        avg-size = 65536;
        max-size = 262144;
      };

      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };

      garbage-collection = {
        interval = "1d";
        default-retention-period = "14d";
      };
    };
  };

  sops.secrets.attic-credentials.sopsFile = ./secrets.yaml;

  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 8080 ];
}
