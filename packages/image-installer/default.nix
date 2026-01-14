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
self.inputs.nixos-generators.nixosGenerate {
  inherit pkgs;
  format = "install-iso";
  modules = [ commonModule ];
}
