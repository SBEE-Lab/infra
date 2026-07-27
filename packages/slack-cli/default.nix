{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "slack-cli";
  version = "4.5.0";

  src = fetchFromGitHub {
    owner = "slackapi";
    repo = "slack-cli";
    rev = "v${version}";
    hash = "sha256-UxBZ94fX52ghhQA7APnT/oej6C+QPqx+GCTFvR/7mZU=";
  };

  vendorHash = "sha256-VTOqQFyco4G4IPRxc2+0YHOM4u7wAQkee3gKvNGNurw=";

  subPackages = [ "." ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/slackapi/slack-cli/internal/version.Version=v${version}"
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
    changelog = "https://github.com/slackapi/slack-cli/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "slack";
    maintainers = [ ];
  };
}
