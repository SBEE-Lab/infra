{
  lib,
  inputs,
  ...
}: {
  flake.overlays = {
    default = lib.composeManyExtensions [
      (final: _prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (final) system;
          config.allowUnfree = true;
        };
        toolz = inputs.toolz.packages.${final.system};
      })
    ];
  };
}
