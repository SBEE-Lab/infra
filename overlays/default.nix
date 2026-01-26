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
    }
  )
]
