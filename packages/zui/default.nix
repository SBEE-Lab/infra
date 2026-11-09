{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage {
  pname = "zui";
  # Match the UI commit selected by the zot v2.1.23 release Makefile.
  version = "0-unstable-2026-10-10";
  src = fetchFromGitHub {
    owner = "project-zot";
    repo = "zui";
    rev = "ce3819cdad951940adc095870cdd16314af579a5";
    hash = "sha256-FwqpghOsuSLRsJN/d7uxO1Tp8RGPZompkdQAdtPeenc=";
  };
  npmDepsHash = "sha256-gcO5P5VRkOGfv6HmdONyXO8kHmC6ZsF+rn6vP+WYR8I=";
  installPhase = ''
    runHook preInstall
    cp -r build $out
    runHook postInstall
  '';
  meta = {
    description = "Web UI for the zot OCI registry";
    homepage = "https://github.com/project-zot/zui";
    license = lib.licenses.asl20;
  };
}
