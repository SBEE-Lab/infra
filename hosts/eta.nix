{
  imports = [
    ../modules/hardware/vultr-vms.nix
    ../modules/disko/ext4-root.nix
    # ../modules/ntfy.nix
  ];

  disko.rootDisk = "/dev/vda";

  networking.hostName = "eta";
  system.stateVersion = "25.05";
}
