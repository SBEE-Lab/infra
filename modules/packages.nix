{
  config,
  pkgs,
  lib,
  ...
}:
let
  hasNvidia = builtins.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  environment.systemPackages = with pkgs; [
    bashInteractive

    # monitoring
    nvme-cli
    pciutils
    lsof
    (if hasNvidia then btop-cuda else btop)
    iperf3
    hyperfine
    perf
    ookla-speedtest
    somo

    # core tools
    git
    openssl
    (lib.hiPrio uutils-coreutils-noprefix)
    (lib.hiPrio uutils-findutils)
    (lib.hiPrio uutils-diffutils)
    python3
    ripgrep
    lftp
    curl
    wget
    tree
    jq
    pv
    fd
    rsync
    rclone
    sd
    nix-output-monitor
  ];
}
