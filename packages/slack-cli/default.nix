{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "slack-cli";
  version = "4.13.0";

  src = fetchFromGitHub {
    owner = "slackapi";
    repo = "slack-cli";
    rev = "v${finalAttrs.version}";
    hash = "sha256-3QhJ6wUbcBeN2LAeL2EK3zUQvQ+kig3sS+tr+x8pbaI=";
  };

  vendorHash = "sha256-GjKNE9PQIENvdnUUplqQNPvYh5zjRv0HtAvKy2bCTiE=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/slackapi/slack-cli/internal/version.Version=v${finalAttrs.version}"
  ];

  doCheck = false;

  postInstall = ''
    mv "$out/bin/slack-cli" "$out/bin/slack"
  '';

  doInstallCheck = stdenv.buildPlatform.canExecute stdenv.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    SLACK_DISABLE_TELEMETRY=true "$out/bin/slack" version --skip-update

    runHook postInstallCheck
  '';

  meta = {
    description = "Slack command-line interface";
    homepage = "https://github.com/slackapi/slack-cli";
    changelog = "https://github.com/slackapi/slack-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "slack";
    maintainers = [ ];
  };
})
