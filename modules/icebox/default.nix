# icebox - Database sync and snapshot management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.icebox;

  databaseModule = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this database";

      syncUrl = lib.mkOption {
        type = lib.types.str;
        description = "URL to sync from (rsync://, gs://, https://, etc.)";
      };

      syncMethod = lib.mkOption {
        type = lib.types.enum [
          "rsync"
          "rclone"
          "wget"
          "script"
        ];
        default = "rsync";
        description = "Sync method to use";
      };

      syncArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional arguments for sync command";
      };

      syncScript = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Custom sync script (when syncMethod = script)";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "monthly";
        description = "Systemd calendar schedule (weekly, monthly, *-*-01, etc.)";
      };

      postSync = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to run after successful sync";
      };
    };
  };

  # Generate sync command for a database
  mkSyncCommand =
    name: db:
    let
      destDir = "${cfg.root}/${name}";
    in
    if db.syncMethod == "script" then
      db.syncScript
    else if db.syncMethod == "rsync" then
      ''
        ${pkgs.rsync}/bin/rsync -avz --progress ${lib.concatStringsSep " " db.syncArgs} \
          "${db.syncUrl}" "${destDir}/"
      ''
    else if db.syncMethod == "rclone" then
      ''
        ${pkgs.rclone}/bin/rclone sync ${lib.concatStringsSep " " db.syncArgs} \
          "${db.syncUrl}" "${destDir}" --progress
      ''
    else if db.syncMethod == "wget" then
      ''
        ${pkgs.wget}/bin/wget -N -P "${destDir}" ${lib.concatStringsSep " " db.syncArgs} \
          "${db.syncUrl}"
      ''
    else
      throw "Unknown sync method: ${db.syncMethod}";

  # Filter enabled databases
  enabledDatabases = lib.filterAttrs (_: db: db.enable) cfg.databases;
in
{
  options.services.icebox = {
    enable = lib.mkEnableOption "icebox database manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3.pkgs.callPackage ../../packages/icebox { };
      description = "icebox package to use";
    };

    root = lib.mkOption {
      type = lib.types.path;
      default = "/workspace/shared/databases";
      description = "Root directory for databases";
    };

    databases = lib.mkOption {
      type = lib.types.attrsOf databaseModule;
      default = { };
      description = "Database configurations";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install icebox CLI
    environment.systemPackages = [ cfg.package ];

    # Create database directories
    systemd.tmpfiles.rules = [
      "d ${cfg.root} 0755 root users -"
    ]
    ++ (lib.mapAttrsToList (name: _: "d ${cfg.root}/${name} 0755 root users -") enabledDatabases);

    # Generate sync services
    systemd.services = lib.mapAttrs' (
      name: db:
      lib.nameValuePair "icebox-sync-${name}" {
        description = "Sync ${name} database";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          Nice = 19;
          IOSchedulingClass = "idle";
          TimeoutStartSec = "24h";
        };

        path = [ pkgs.coreutils ];

        script = ''
          set -euo pipefail
          echo "Starting sync for ${name}..."
          cd "${cfg.root}/${name}"

          ${mkSyncCommand name db}

          ${lib.optionalString (db.postSync != "") ''
            echo "Running post-sync commands..."
            ${db.postSync}
          ''}

          echo "Sync completed for ${name}"
        '';
      }
    ) enabledDatabases;

    # Generate timers
    systemd.timers = lib.mapAttrs' (
      name: db:
      lib.nameValuePair "icebox-sync-${name}" {
        description = "Timer for ${name} database sync";
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = db.schedule;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      }
    ) enabledDatabases;
  };
}
