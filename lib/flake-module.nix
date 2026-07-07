{ inputs, ... }:
{
  flake.lib.sbee.monitoring = import ./monitoring.nix {
    lib = inputs.nixpkgs.lib;
  };
}
