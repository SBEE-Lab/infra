{
  config,
  pkgs,
  ...
}:
{
  systemd.timers.update-prefetch.timerConfig.Persistent = true;
  systemd.services.update-prefetch = {
    startAt = "hourly";
    path = [
      config.nix.package
      pkgs.curl
    ];
    script = ''
      set -euo pipefail
      p=$(curl -fsSL "https://nixbot.sjanglab.org/nix-outputs/github/SBEE-Lab/infra/main/checks.${pkgs.stdenv.hostPlatform.system}.nixos-${config.networking.hostName}")
      nix-store --option narinfo-cache-negative-ttl 0 --add-root /run/next-system -r "$p"
    '';
    serviceConfig = {
      Type = "oneshot";
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
    };
  };

  services.sbee.jobResults.extraJobs.update-prefetch.scheduled = true;
}
