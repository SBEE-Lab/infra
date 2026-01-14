{
  self,
  lib,
  pkgs,
  ...
}:
let
  commonModules = {
    imports = [
      self.inputs.nixos-images.nixosModules.kexec-installer
      self.inputs.nixos-images.nixosModules.noninteractive
      {
        system.kexec-installer.name = "nixos-kexec-installer-noninteractive";
        services.openssh.ports = [ 10022 ];
        boot.supportedFilesystems = lib.mkForce [
          "ext4"
          "xfs"
          "btrfs"
        ];
      }
    ];
  };
in
(pkgs.nixos commonModules).config.system.build.kexecInstallerTarball
