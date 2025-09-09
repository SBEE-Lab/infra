{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ipmitool
    nvme-cli
    ethtool
    pciutils
    python3
    git
    lsof
    ripgrep
    htop
    wget
    openssl
    jq
    rsync
    (neovim.override {
      vimAlias = true;
      withRuby = false;
    })
  ];
}
