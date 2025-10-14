{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.docs = pkgs.mkShellNoCC {inputsFrom = [config.packages.docs];};

    packages = {
      docs =
        pkgs.runCommand "docs"
        {
          buildInputs = [pkgs.zensical];
          files = pkgs.lib.fileset.toSource {
            root = ../.;
            fileset = pkgs.lib.fileset.unions [
              ../zensical.toml
              ../docs
            ];
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
          exclude = [
            "docker:.*"
          ];
        };
        remap = {
          "https://sjanglab.org" = site;
        };
        site = config.packages.docs;
      };
    };
  };
}
