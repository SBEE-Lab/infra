{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  zui,
}:
let
  version = "2.1.23";
  extensions = [
    "events"
    "imagetrust"
    "lint"
    "metrics"
    "mgmt"
    "profile"
    "scrub"
    "search"
    "sync"
    "ui"
    "userprefs"
  ];
  binaryType = "-${lib.concatStringsSep "-" extensions}";
in
buildGo127Module (finalAttrs: {
  pname = "zot";
  inherit version;
  src = fetchFromGitHub {
    owner = "project-zot";
    repo = "zot";
    tag = "v${version}";
    hash = "sha256-Q21qFoZzOpJe7oJP4RSGiBvhPF9znCF2ndegsVSHQnY=";
  };
  vendorHash = "sha256-ILHn4EUCHLpwdgSj/CBlX58R1D2zJhr+H6HkcAOdhis=";
  subPackages = [ "cmd/zot" ];
  tags = extensions;
  buildFlags = [ "-buildmode=pie" ];
  env = {
    CGO_ENABLED = 0;
    GOEXPERIMENT = "jsonv2";
  };
  preBuild = ''
    cp -r --no-preserve=mode ${zui} pkg/extensions/build
  '';
  ldflags = [
    "-s"
    "-w"
    "-X zotregistry.dev/zot/v2/pkg/buildinfo.ReleaseTag=v${version}"
    "-X zotregistry.dev/zot/v2/pkg/buildinfo.Commit=v${version}-0-gd7915e8"
    "-X zotregistry.dev/zot/v2/pkg/buildinfo.BinaryType=${binaryType}"
    "-X zotregistry.dev/zot/v2/pkg/buildinfo.GoVersion=go${finalAttrs.passthru.go.version}"
  ];
  # Upstream integration tests require network services and image fixtures.
  doCheck = false;
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/zot" --version | grep -F '${version}'
    "$out/bin/zot" --version | grep -F -- '${binaryType}'
    runHook postInstallCheck
  '';
  meta = {
    description = "OCI image registry with authentication, search and retention";
    homepage = "https://zotregistry.dev";
    license = lib.licenses.asl20;
    mainProgram = "zot";
  };
})
