# db-sync - Database sync and snapshot management
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.db-sync;

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

  ntfyUrl = "https://ntfy.sjanglab.org/gatus";

  # Helper to install a script with @var@ substitutions
  mkScript =
    name: file:
    pkgs.writeShellScriptBin name (
      builtins.replaceStrings [ "@dbRoot@" "@ntfyUrl@" ] [ (toString cfg.root) ntfyUrl ] (
        builtins.readFile ./scripts/${file}
      )
    );
in
{
  options.services.db-sync = {
    enable = lib.mkEnableOption "database sync manager";

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
    # CLI utilities
    environment.systemPackages = [
      (mkScript "db-list" "db-list.sh")
      (mkScript "db-freeze" "db-freeze.sh")
      (mkScript "db-thaw" "db-thaw.sh")
    ];

    # Create database directories
    systemd.tmpfiles.rules = [
      "d ${cfg.root} 0755 root users -"
    ]
    ++ (lib.mapAttrsToList (name: _: "d ${cfg.root}/${name} 0755 root users -") enabledDatabases);

    # Generate sync services + failure notification template unit
    systemd.services = {
      # Template unit for failure notification (%i = failed unit name)
      "db-sync-notify-failure@" = {
        description = "Notify db-sync failure for %i";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "db-sync-notify-failure" ''
            unit="$1"
            ${pkgs.curl}/bin/curl -sf --max-time 10 \
              -H "Title: DB sync failed: $unit" \
              -H "Priority: high" \
              -H "Tags: warning,db-sync" \
              -d "$(${pkgs.systemd}/bin/journalctl -u "$unit" --since '1 hour ago' --no-pager -n 30)" \
              "${ntfyUrl}"
          ''} %i";
        };
      };
    }
    // lib.mapAttrs' (
      name: db:
      lib.nameValuePair "db-sync-${name}" {
        description = "Sync ${name} database";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        unitConfig = {
          OnFailure = "db-sync-notify-failure@db-sync-${name}.service";
        };

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
      lib.nameValuePair "db-sync-${name}" {
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
