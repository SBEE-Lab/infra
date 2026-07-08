{
  cfg,
  helper,
  lib,
  pkgs,
}:
let
  enabledDatabases = lib.filterAttrs (_: db: db.enable) cfg.databases;

  rcloneConf = pkgs.writeText "biodb-rclone.conf" ''
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

  syncDest =
    name: db: "${cfg.root}/${name}${lib.optionalString (db.syncSubdir != "") "/${db.syncSubdir}"}";

  mkSyncPackage =
    name: db:
    pkgs.writeShellApplication {
      name = "biodb-${name}";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnutar
        pkgs.gzip
        pkgs.rclone
      ];
      text = ''
        set -euo pipefail
        echo "Starting sync for ${name}..."

        syncDest=${lib.escapeShellArg (syncDest name db)}
        mkdir -p "$syncDest"
        rclone sync \
          --config ${rcloneConf} \
          ${lib.concatMapStringsSep " " lib.escapeShellArg db.syncArgs} \
          ${lib.escapeShellArg db.syncUrl} "$syncDest" \
          --verbose --stats-one-line

        ${lib.optionalString (db.postSync != "") ''
          echo "Running post-sync commands..."
          cd ${lib.escapeShellArg "${cfg.root}/${name}"}
          ${db.postSync}
        ''}

        echo "Sync completed for ${name}"
      '';
    };

  syncPackages = lib.mapAttrs mkSyncPackage enabledDatabases;

  services = lib.mapAttrs' (
    name: db:
    lib.nameValuePair "biodb-${name}" {
      description = "Sync ${name} database";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe syncPackages.${name};
        Nice = 19;
        IOSchedulingClass = "idle";
        TimeoutStartSec = db.timeout;
      };
    }
  ) enabledDatabases;

  timers = lib.mapAttrs' (
    name: db:
    lib.nameValuePair "biodb-${name}" {
      description = "Timer for ${name} database sync";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = db.schedule;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    }
  ) enabledDatabases;
in
{
  inherit enabledDatabases;

  systemPackages = [ helper ];

  inherit services timers;
}
