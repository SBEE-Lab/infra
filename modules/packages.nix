{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # monitoring
    nvme-cli
    pciutils
    lsof
    btop
    iperf3
    hyperfine
    ookla-speedtest
    unstable.somo

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
    bashInteractive

    # with research
    dvc-with-remotes
    ntfy-sh
    parallel
    aria2
    b3sum
    rblake3sum

    # utility
    zellij
    minio-client
    ts
    sd
  ];
}
