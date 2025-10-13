{
  imports = [
    ../modules/disko/xfs-root.nix
    ../modules/xrdp.nix
    ../modules/nvidia.nix
    ../modules/harmonia
  ];

  disko.rootDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_4TB_S7DPNU0Y404280K";

  networking.hostName = "psi";

  system.stateVersion = "25.05";
}
