{ self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = {
        slack-cli = pkgs.callPackage ./slack-cli { };
        updater = pkgs.callPackage ./updater { };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        installer = pkgs.callPackage ./image-installer { inherit pkgs self; };
        kexec = pkgs.callPackage ./kexec-installer { inherit pkgs self; };
      };
    };
}
