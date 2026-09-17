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
      ../image-installer/nix-settings.nix
      {
        system.kexec-installer.name = "nixos-kexec-installer-noninteractive";
        services.openssh.ports = [ 10022 ];
        boot.supportedFilesystems = lib.mkForce [
          "ext4"
          "xfs"
          "btrfs"
          "zfs"
        ];
      }
    ];
  };
in
(pkgs.nixos commonModules).config.system.build.kexecInstallerTarball
