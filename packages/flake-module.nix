{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        sotp = pkgs.callPackage ./sotp.nix { };
      }
      // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
        installer = pkgs.callPackage ./installer-iso { inherit self; };
        kexec = pkgs.callPackage ./custom-kexec { inherit self; };
      };
    };
}
