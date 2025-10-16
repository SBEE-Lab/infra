# https://github.com/TUM-DSE/doctor-cluster-config/tree/04a6acec04fbed055511b8f03055b117e76683d3/modules/auto-upgrade.nix
{
  pkgs,
  lib,
  ...
}: {
  system.autoUpgrade.enable = lib.mkDefault true;
  system.autoUpgrade.flake = "github:SBEE-lab/infra";
  system.autoUpgrade.flags = [
    "--option"
    "accept-flake-config"
    "true"
  ];

  # add a random jitter so not all machines reboot at the same time.
  systemd.timers.auto-reboot.timerConfig.RandomizedDelaySec = 60 * 20;

  systemd.services.auto-reboot = {
    path = [
      pkgs.systemd
      pkgs.util-linux
    ];
    # The last saturday in a month
    startAt = "Sat *-*~07/1";
    script = ''
      booted="$(readlink /run/booted-system/{initrd,kernel,kernel-modules})"
      built="$(readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"
      if [ "''${booted}" = "''${built}" ]; then
        echo "No kernel update... skipping reboot"
      else
        # reboot in 24 hours
        msg=$(shutdown -r +${toString (60 * 24)} 2>&1)
        echo "$msg" | wall
      fi
    '';
  };
}
