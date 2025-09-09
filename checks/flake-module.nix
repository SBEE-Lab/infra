{
  imports = [ ./sops.nix ];
  perSystem =
    {
      self',
      lib,
      ...
    }:
    let
      # packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
    in
    {
      checks = {
        inherit (self') formatter;
        inherit (self'.packages) terraform-validate sops-check;
      }
      # // lib.optionalAttrs (system == "x86_64-linux") {
      #   inherit (self'.packages) installer;
      # }
      // devShells;
    };
}
