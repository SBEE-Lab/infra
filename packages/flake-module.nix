{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        sotp = pkgs.callPackage ./sotp.nix { };
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
        installer = pkgs.callPackage ./install-iso { inherit self; };
      };
    };
}
