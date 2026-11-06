{
  buildNpmPackage,
  importNpmLock,
  lib,
  makeWrapper,
  nodejs_24,
}:

buildNpmPackage {
  pname = "slack-group-sync";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./src
      ./test
    ];
  };

  # Node 24 runs the TypeScript sources directly, so there is nothing to
  # compile; the build step type-checks and runs the tests.
  nodejs = nodejs_24;
  npmDeps = importNpmLock {
    npmRoot = ./.;
  };
  inherit (importNpmLock) npmConfigHook;
  npmBuildScript = "ci";
  nativeBuildInputs = [ makeWrapper ];

  # Node refuses to strip types from files under a node_modules directory,
  # which is where npm's own install step would put this package.
  installPhase = ''
    runHook preInstall
    npm prune --omit=dev --offline --no-audit --no-fund
    mkdir -p "$out/share/slack-group-sync"
    cp -r package.json src node_modules "$out/share/slack-group-sync/"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/slack-group-sync" \
      --add-flags "--disable-warning=ExperimentalWarning $out/share/slack-group-sync/src/main.ts"
    runHook postInstall
  '';

  meta = {
    description = "Keep authentik groups equal to the lab's Slack user groups";
    mainProgram = "slack-group-sync";
  };
}
