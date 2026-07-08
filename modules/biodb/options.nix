{ lib }:
let
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

      timeout = lib.mkOption {
        type = lib.types.str;
        default = "24h";
        description = "systemd TimeoutStartSec for this database sync service.";
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
in
{
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
}
