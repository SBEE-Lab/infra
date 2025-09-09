{
  self,
  pkgs,
  ...
}:
let
  commonModule = {
    imports = [
      ./base-config.nix
      ./network.nix
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
