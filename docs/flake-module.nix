{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.mkdocs = pkgs.mkShellNoCC { inputsFrom = [ config.packages.docs ]; };
      packages = {
        docs =
          pkgs.runCommand "docs"
            {
              buildInputs = with pkgs.python3.pkgs; [
                mkdocs-material
              ];
              files = pkgs.lib.fileset.toSource {
                root = ../.;
                fileset = pkgs.lib.fileset.unions [
                  ../mkdocs.yml
                  ../docs
                ];
              };
            }
            ''
              cp --no-preserve=mode -r $files/* .
              mkdocs build --strict --site-dir $out
            '';
      };
    };
}
