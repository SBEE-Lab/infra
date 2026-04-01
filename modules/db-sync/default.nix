# db-sync - Database sync and snapshot management
#
# All databases are synced via rclone. Remotes are configured in rcloneConf
# below. Each database entry specifies a syncUrl using these remote names.
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
        description = "rclone remote path (e.g. ncbi:blast/db/, ebi:pub/databases/...)";
      };

      syncArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional rclone arguments (--include, --exclude, --transfers, etc.)";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "monthly";
        description = "Systemd calendar schedule (weekly, monthly, *-*-01, etc.)";
      };

      syncSubdir = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Subdirectory within the database dir to sync into (e.g. .staging for tar archives)";
      };

      postSync = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to run after successful sync (e.g. tar extraction)";
      };
    };
  };

  enabledDatabases = lib.filterAttrs (_: db: db.enable) cfg.databases;

  # rclone remote configuration
  rcloneConf = pkgs.writeText "db-sync-rclone.conf" ''
    [ncbi]
    type = ftp
    host = ftp.ncbi.nlm.nih.gov
    user = anonymous
    pass = ${cfg.rcloneFtpPass}

    [ebi]
    type = http
    url = https://ftp.ebi.ac.uk

    [pdbj]
    type = http
    url = https://ftp.pdbj.org
  '';

  # Helper to install a script with @var@ substitutions
  mkScript =
    name: file:
    pkgs.writeShellScriptBin name (
      builtins.replaceStrings [ "@dbRoot@" ] [ (toString cfg.root) ] (builtins.readFile ./scripts/${file})
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

    rcloneFtpPass = lib.mkOption {
      type = lib.types.str;
      default = "30GVq-Od-Wrx9TjapNbWlw";
      description = "rclone-obscured password for anonymous FTP (obscured empty string)";
    };
  };

  config = lib.mkIf cfg.enable {
    # CLI utilities
    environment.systemPackages = [
      (mkScript "db-list" "db-list.sh")
      (mkScript "db-sync-all" "db-sync-all.sh")
      (mkScript "db-sync-stop" "db-sync-stop.sh")
      (mkScript "db-sync-status" "db-sync-status.sh")
      (mkScript "db-freeze" "db-freeze.sh")
      (mkScript "db-thaw" "db-thaw.sh")
    ];

    # Create database directories
    systemd.tmpfiles.rules = [
      "d ${cfg.root} 0755 root users -"
    ]
    ++ (lib.mapAttrsToList (
      name: db:
      "d ${cfg.root}/${name}${
        lib.optionalString (db.syncSubdir != "") "/${db.syncSubdir}"
      } 0755 root users -"
    ) enabledDatabases);

    # Generate sync services
    systemd.services = lib.mapAttrs' (
      name: db:
      lib.nameValuePair "db-sync-${name}" {
        description = "Sync ${name} database";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          Nice = 19;
          IOSchedulingClass = "idle";
          TimeoutStartSec = "24h";
        };

        path = [
          pkgs.coreutils
          pkgs.gnutar
          pkgs.gzip
        ];

        script = ''
          set -euo pipefail
          echo "Starting sync for ${name}..."

          syncDest="${cfg.root}/${name}/${db.syncSubdir}"
          mkdir -p "$syncDest"
          ${pkgs.rclone}/bin/rclone sync \
            --config ${rcloneConf} \
            ${lib.concatMapStringsSep " " lib.escapeShellArg db.syncArgs} \
            "${db.syncUrl}" "$syncDest" \
            --verbose --stats-one-line

          ${lib.optionalString (db.postSync != "") ''
            echo "Running post-sync commands..."
            cd "${cfg.root}/${name}"
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
