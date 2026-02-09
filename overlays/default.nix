{ inputs }:
[
  (
    final: _prev:
    let
      unstable = import inputs.nixpkgs-unstable {
        inherit (final.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };
    in
    {
      inherit (unstable)
        ntfy-sh
        somo
        opentofu
        buildbot
        buildbot-worker
        buildbot-plugins
        perf
        ;
      inherit unstable;

      # Text Embeddings Inference (TEI) - uses CUDA from host config
      text-embeddings-inference = final.callPackage ../packages/text-embeddings-inference {
        cudaSupport = final.config.cudaSupport or false;
      };
    }
  )
]
