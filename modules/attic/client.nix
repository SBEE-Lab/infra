{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.attic-client;
in {
  options.services.attic-client = {
    enable = lib.mkEnableOption "attic client for infra cache";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "sbee";
      description = "Name to register the attic server as";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cache.sjanglab.org";
      description = "URL of the attic server";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "infra";
      description = "Name of the cache to use";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "attic-token";
      description = "Name of the sops secret containing the attic token";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.attic-client];

    # Create attic config directory
    systemd.tmpfiles.rules = [
      "d /root/.config/attic 0700 root root -"
    ];

    # Configure attic client with token from sops
    systemd.services.attic-client-setup = {
      description = "Setup attic client configuration";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        TOKEN=$(cat ${config.sops.secrets.${cfg.tokenSecret}.path})
        ${pkgs.attic-client}/bin/attic login ${cfg.serverName} ${cfg.serverUrl} "$TOKEN"
      '';
    };

    # Note: sops.secrets.attic-token must be defined in the host's configuration
    # or in commonModules, pointing to the host's sops file
  };
}
