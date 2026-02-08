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
        icebox = pkgs.python3.pkgs.callPackage ./icebox { };
        text-embeddings-inference = pkgs.callPackage ./text-embeddings-inference { cudaSupport = false; };
        zensical = pkgs.python3.pkgs.callPackage ./zensical { };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        installer = pkgs.callPackage ./image-installer { inherit pkgs self; };
        kexec = pkgs.callPackage ./kexec-installer { inherit pkgs self; };
        text-embeddings-inference-cuda = pkgs.callPackage ./text-embeddings-inference {
          cudaSupport = true;
        };
      };
    };
}
