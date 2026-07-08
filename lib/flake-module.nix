{ inputs, ... }:
{
  flake.lib.sbee = {
    backup = import ./backup.nix {
      lib = inputs.nixpkgs.lib;
    };
    monitoring = import ./monitoring.nix {
      lib = inputs.nixpkgs.lib;
    };
  };
}
