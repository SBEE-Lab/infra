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
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cache.sjanglab.org";
    };

    cacheName = lib.mkOption {
      type = lib.types.str;
      default = "infra";
    };

    tokenSecret = lib.mkOption {
      type = lib.types.str;
      default = "attic-token";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [pkgs.attic-client];

    systemd.tmpfiles.rules = [
      "d /root/.config/attic 0700 root root -"
    ];

    sops.templates."attic-netrc" = {
      mode = "0400";
      content = ''
        machine cache.sjanglab.org
        password ${config.sops.placeholder.${cfg.tokenSecret}}
      '';
    };

    nix.settings.netrc-file = config.sops.templates."attic-netrc".path;

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
  };
}
