{ inputs, self, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      packages = {
        infra-alert-bridge = pkgs.callPackage ./infra-alert-bridge { };
        inherit (inputs.rag-nix.packages.${pkgs.stdenv.hostPlatform.system})
          omnigraph-cli
          omnigraph-server
          ;
        slack-cli = pkgs.callPackage ./slack-cli { };
        updater = pkgs.callPackage ./updater { };
      }
      // lib.optionalAttrs pkgs.stdenv.isLinux {
        inherit (inputs.rag-nix.packages.${pkgs.stdenv.hostPlatform.system}) omnigraph;
        installer = pkgs.callPackage ./image-installer { inherit pkgs self; };
        kexec = pkgs.callPackage ./kexec-installer { inherit pkgs self; };
        text-embeddings-inference = pkgs.callPackage ./text-embeddings-inference {
          cudaSupport = false;
        };
        text-embeddings-inference-cuda = pkgs.callPackage ./text-embeddings-inference {
          cudaSupport = true;
        };
      };
    };
}
