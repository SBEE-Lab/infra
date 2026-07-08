{ pkgs }:
pkgs.writeTextFile {
  name = "biodb-helper";
  destination = "/bin/biodb-helper";
  executable = true;
  text = "#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./scripts/biodb-helper.py;
}
