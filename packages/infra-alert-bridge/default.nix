{
  buildNpmPackage,
  importNpmLock,
  lib,
}:

buildNpmPackage {
  pname = "infra-alert-bridge";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./wrangler.toml
      ./src
      ./test
      ./migrations
    ];
  };

  npmDeps = importNpmLock {
    npmRoot = ./.;
  };
  inherit (importNpmLock) npmConfigHook;

  npmBuildScript = "ci";

  env = {
    WRANGLER_SEND_METRICS = "false";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/infra-alert-bridge"
    cp -r dist migrations wrangler.toml package.json "$out/share/infra-alert-bridge/"
    runHook postInstall
  '';

  meta = {
    description = "Cloudflare Worker bridge from Alertmanager and healthchecks.io to Slack";
    license = lib.licenses.mit;
  };
}
