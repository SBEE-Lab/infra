{
  self,
  lib,
  pkgs,
  ...
}:
let
  modules = {
    imports = [
      self.inputs.nixos-images.nixosModules.kexec-installer
      self.inputs.nixos-images.nixosModules.noninteractive
      ../image-installer/nix-settings.nix
      ./module.nix
      {
        system.kexec-installer.name = "nixos-ephemeral-kexec-installer";
        services.openssh.ports = [ 10022 ];
        # noninteractive provides its own size-optimized ZFS kernel module
        # and userspace. Listing zfs here would also load the full NixOS ZFS
        # module and make both variants install the same systemd units.
        boot.supportedFilesystems = lib.mkForce [
          "ext4"
          "xfs"
          "btrfs"
        ];
      }
    ];
  };
in
(pkgs.nixos modules).config.system.build.kexecInstallerTarball
