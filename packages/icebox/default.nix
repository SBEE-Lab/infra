{
  lib,
  buildPythonApplication,
  hatchling,
  click,
  makeWrapper,
  rsync,
  rclone,
  wget,
}:
let
  runtimeDeps = [
    rsync
    rclone
    wget
  ];
in
buildPythonApplication {
  pname = "icebox";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ hatchling ];
  dependencies = [ click ];

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/icebox \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';

  meta = {
    description = "Keep databases fresh, freeze when needed";
    mainProgram = "icebox";
  };
}
