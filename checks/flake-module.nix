{ inputs, self, ... }:
{
  imports = [
    ../modules/sops/checks.nix
  ];

  flake.herculesCI = import ./effects.nix { inherit inputs self; };

  perSystem =
    {
      self',
      system,
      lib,
      pkgs,
      ...
    }:
    let
      packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
      nixosMachines = lib.optionalAttrs (system == "x86_64-linux") (
        lib.mapAttrs' (name: lib.nameValuePair "nixos-${name}") (
          lib.mapAttrs (_: config: config.config.system.build.toplevel) self.nixosConfigurations
        )
      );
      # NixOS VM tests for module behaviour that host builds cannot exercise.
      nixosModules = lib.optionalAttrs (system == "x86_64-linux") {
        nixosModule-agentgateway = pkgs.callPackage ../modules/agentgateway/test.nix { };
      };
    in
    {
      treefmt = {
        flakeCheck = true;
      };
      checks = {
        inherit (self') formatter;
      }
      // nixosMachines
      // nixosModules
      // packages
      // devShells;
    };
}
