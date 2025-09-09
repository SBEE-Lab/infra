{
  self,
  pkgs,
  ...
}:
let
  commonModules = {
    imports = [
      ../installer-iso/base-config.nix
      ../installer-iso/nix-settings.nix
      ./safety-reboot.nix
      self.inputs.nixos-images.nixosModules.kexec-installer
      self.inputs.nixos-images.nixosModules.noninteractive
      { system.kexec-installer.name = "nixos-kexec-instalelr-noninteractive"; }
    ];
    _module.args.inputs = self.inputs;
  };
in
(pkgs.nixos commonModules).config.system.build.kexecInstallerTarball
