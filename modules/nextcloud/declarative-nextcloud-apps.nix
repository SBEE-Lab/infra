{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.nextcloudAppStoreApps;
  occ = lib.getExe config.services.nextcloud.occ;
  jq = lib.getExe pkgs.jq;
  appArgs = lib.escapeShellArgs (lib.unique cfg.apps);
in
{
  options.services.sbee.nextcloudAppStoreApps = {
    enable = lib.mkEnableOption "declarative Nextcloud App Store apps";

    apps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "integration_slack" ];
      description = ''
        Nextcloud App Store app IDs to keep installed and enabled with occ.
        These apps are intentionally not pinned in Nix and are updated by
        Nextcloud's App Store updater.
      '';
    };

    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable the NixOS Nextcloud App Store updater for apps installed from the
        App Store.
      '';
    };

    autoUpdateStartAt = lib.mkOption {
      type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
      default = "05:00:00";
      description = "When to run Nextcloud App Store app updates.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.nextcloud.enable;
        message = "services.sbee.nextcloudAppStoreApps requires services.nextcloud.enable = true";
      }
    ];

    services.nextcloud = {
      appstoreEnable = true;
      autoUpdateApps = lib.mkIf cfg.autoUpdate {
        enable = true;
        startAt = cfg.autoUpdateStartAt;
      };
    };

    systemd.services.nextcloud-appstore-apps = {
      description = "Install and enable declarative Nextcloud App Store apps";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nextcloud-setup.service"
      ];
      requires = [ "nextcloud-setup.service" ];
      restartTriggers = [ (builtins.toJSON (lib.unique cfg.apps)) ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.jq ];
      script = ''
        set -euo pipefail

        apps_json="$(${occ} app:list --output=json)"
        for app in ${appArgs}; do
          if ! printf '%s' "$apps_json" | ${jq} -e --arg app "$app" '.enabled[$app] or .disabled[$app]' >/dev/null; then
            ${occ} app:install "$app"
          fi
          ${occ} app:enable "$app"
        done
      '';
    };
  };
}
