{ self, ... }:
{
  imports = [ ./sops.nix ];

  perSystem =
    {
      self',
      system,
      lib,
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
    in
    {
      treefmt = {
        flakeCheck = true;
      };
      checks = {
        inherit (self') formatter;
      }
      // nixosMachines
      // packages
      // devShells;
    };
}
