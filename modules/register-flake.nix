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
  };

  nix.nixPath = builtins.map (name: "${name}=flake:${name}") (builtins.attrNames config.nix.registry);
}
