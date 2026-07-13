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

      packages.docs =
        pkgs.runCommand "docs"
          {
            buildInputs = [ pkgs.zensical ];
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

      checks.docs-linkcheck = pkgs.testers.lycheeLinkCheck rec {
        extraConfig = {
          include_mail = false;
          include_verbatim = true;
          exclude = [
            "docker:.*"
            "file://.*/404.html#__skip"
            # Local and method-specific API examples cannot be validated with
            # the link checker's HTTP GET/HEAD requests.
            "http://10\\.100\\.0\\.2:5000/?$"
            "http://localhost:8000/?$"
            "https://buildbot\\.sjanglab\\.org/(auth/github/callback|webhooks/github)$"
            "https://docling\\.sjanglab\\.org(/.*)?$"
            "https://tei\\.sjanglab\\.org/(embed|rerank)/.*$"
            # Generated source links for new pages do not exist on main until
            # the documentation PR is merged.
            "https://github\\.com/sbee-lab/infra/(raw|edit)/main/docs/.*$"
          ];
          root_dir = "${site}";
        };
        remap = {
          # Check canonical documentation links against this build so pages
          # added by the current branch need not already be published.
          "https://sbee-lab.github.io/infra" = site;
          "https://sjanglab.org" = site;
          "file://(.+)/infra$" = "file://$1";
          "file://(.+)/infra/(.*)" = "file://$1/$2";
          # Resolve directory-style URLs to index.html for fragment checking
          "file://(.+)/([a-z][-a-z0-9]*)#(.*)" = "file://$1/$2/index.html#$3";
        };
        site = config.packages.docs;
      };

      apps.docs-serve = {
        type = "app";
        meta.description = "Serve documentation site locally";
        program = toString (
          pkgs.writeShellScript "docs-serve" ''
            ${pkgs.python3}/bin/python3 -m http.server -d ${config.packages.docs} "''${1:-8000}"
          ''
        );
      };
    };
}
