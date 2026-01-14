# Rsync mirror of borg repos from tau to rho
# Provides redundancy for borg backups (3-2-1 rule)
{
  config,
  pkgs,
  ...
}:
let
  tauWgMgnt = config.networking.sbee.hosts.tau.wg-mgnt;
  mirrorDir = "/backup/borg-mirror";
in
{
  # Ensure mirror directory exists
  systemd.tmpfiles.rules = [
    "d ${mirrorDir} 0750 root root -"
  ];

  # Rsync borg repos from tau
  systemd.services.borg-mirror-sync = {
    description = "Mirror borg repos from tau";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      ${pkgs.rsync}/bin/rsync -avz --delete \
        -e "ssh -p 10022" \
        root@${tauWgMgnt}:/backup/borg/ \
        ${mirrorDir}/
    '';
  };

  systemd.timers.borg-mirror-sync = {
    description = "Daily mirror of borg repos from tau";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00"; # After all borg backups complete
      Persistent = true;
    };
  };
}
