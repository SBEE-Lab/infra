{
  self,
  pkgs,
  ...
}:
let
  commonModule = {
    imports = [
      ./base-config.nix
      ./networks/idc.nix
      ./nix-settings.nix
    ];
    _module.args.inputs = self.inputs;
  };
in
(pkgs.nixos [
  "${pkgs.path}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  commonModule
]).config.system.build.isoImage
