{
  perSystem =
    { config, pkgs, ... }:
    let
      inherit (pkgs.lib) fileset;
      docsFiles = fileset.unions [
        ../zensical.toml
        (fileset.fileFilter (file: file.hasExt "md" || file.hasExt "css") ../docs)
      ];
    in
    {
      devShells.docs = pkgs.mkShellNoCC { inputsFrom = [ config.packages.docs ]; };

      packages = {
        docs =
          pkgs.runCommand "docs"
            {
              buildInputs = [ config.packages.zensical ];
              files = fileset.toSource {
                root = ../.;
                fileset = docsFiles;
              };
            }
            ''
              cp --no-preserve=mode -r $files/* .

              zensical build --clean

              mkdir -p $out
              cp -r site/* $out/
            '';

        docs-linkcheck = pkgs.testers.lycheeLinkCheck rec {
          extraConfig = {
            include_mail = true;
            include_verbatim = true;
            exclude = [ "docker:.*" ];
          };
          remap = {
            "https://sjanglab.org" = site;
          };
          site = config.packages.docs;
        };
      };

      apps.docs-serve = {
        type = "app";
        program = toString (
          pkgs.writeShellScript "docs-serve" ''
            ${pkgs.python3}/bin/python3 -m http.server -d ${config.packages.docs} "''${1:-8000}"
          ''
        );
      };
    };
}
