{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "docker_auth";
  version = "1.14.0";

  src = fetchFromGitHub {
    owner = "cesanta";
    repo = "docker_auth";
    tag = finalAttrs.version;
    hash = "sha256-WeqgNxuLuckdcQj5AluyDRBuCuyoIaiiTM7AN+Dgr8s=";
  };

  modRoot = "auth_server";
  vendorHash = "sha256-dbSSmQ+Kl28NQ+4tw8wYy6oRcSQd88QLgaWe4wB3OMg=";

  ldflags = [
    "-X main.Version=${finalAttrs.version}"
    "-X main.BuildID=nix"
  ];

  postInstall = ''
    mv "$out/bin/auth_server" "$out/bin/docker_auth"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/docker_auth" -h >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Authentication server for Docker Registry 2";
    homepage = "https://github.com/cesanta/docker_auth";
    changelog = "https://github.com/cesanta/docker_auth/releases/tag/${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "docker_auth";
    platforms = lib.platforms.unix;
  };
})
