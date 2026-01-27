{
  self,
  inputs,
  config,
  ...
}:
{
  srvos.flake = self;
  srvos.registerSelf = true;

  nix.registry = {
    nixpkgs.flake = inputs.nixpkgs;
    nixpkgs-unstable.flake = inputs.nixpkgs-unstable;
  };

  nix.nixPath = builtins.map (name: "${name}=flake:${name}") (builtins.attrNames config.nix.registry);
}
