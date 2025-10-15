{
  imports = [
    ../modules/hardware/vultr-vms.nix
    ../modules/disko/ext4-root.nix
    ../modules/ntfy.nix
    ../modules/attic/reverse-proxy.nix
    ../modules/buildbot/reverse-proxy.nix
    ../modules/monitoring/vector
    ../modules/monitoring/reverse-proxy.nix
  ];

  disko.rootDisk = "/dev/vda";

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
