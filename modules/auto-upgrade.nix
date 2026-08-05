{
  config,
  pkgs,
  ...
}:
{
  # Fetch and apply system updates from buildbot CI.
  # Adapted from: https://github.com/TUM-DSE/doctor-cluster-config/blob/master/modules/auto-upgrade.nix
  systemd.services.auto-upgrade = {
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
      Type = "oneshot";
    };
    path = [
      config.nix.package
      config.systemd.package
      pkgs.coreutils
      pkgs.curl
    ];
    script = ''
      set -euo pipefail

      hostname=$(uname -n)
      p=$(curl -fsSL "https://nixbot.sjanglab.org/nix-outputs/github/SBEE-Lab/infra/main/default.checks.${pkgs.stdenv.buildPlatform.system}.nixos-$hostname")

      if [[ "$(readlink /run/current-system)" == "$p" ]]; then
        echo "Already at $p, nothing to do"
        exit 0
      fi

      echo "Updating to $p"
      nix-store --option narinfo-cache-negative-ttl 0 --realise "$p"
      nix-env --profile /nix/var/nix/profiles/system --set "$p"

      /nix/var/nix/profiles/system/bin/switch-to-configuration switch
    '';
  };

  systemd.timers.auto-upgrade = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitInactiveSec = "1d";
    };
  };

  # Reboot on the last Saturday of each month if kernel changed.
  systemd.timers.auto-reboot.timerConfig.RandomizedDelaySec = 60 * 20;

  systemd.services.auto-reboot = {
    path = [
      pkgs.systemd
      pkgs.util-linux
    ];
    startAt = "Sat *-*~07/1";
    script = ''
      booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
      built="$(readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"
      if [ "''${booted}" = "''${built}" ]; then
        echo "No kernel update... skipping reboot"
      else
        msg=$(shutdown -r +${toString (60 * 24)} 2>&1)
        echo "$msg" | wall
      fi
    '';
  };
}
