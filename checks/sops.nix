# https://github.com/nix-community/infra/tree/e25c9f72a56641d5b4646d2711e59ccc63e171b8/dev/sops.nix
{
  perSystem =
    { pkgs, ... }:
    {
      packages.sops-check =
        pkgs.runCommand "sops-check"
          {
            buildInputs = with pkgs; [
              diffutils
              nix
              sops
              yq-go
              fd
            ];
            files = pkgs.lib.fileset.toSource {
              root = ../.;
              fileset = pkgs.lib.fileset.unions [
                (pkgs.lib.fileset.fromSource (pkgs.lib.sources.sourceFilesBySuffices ../. [ ".yaml" ]))
                ../hosts
                ../.sops.nix
                ../pubkeys.json
                ../modules
              ];
            };
          }
          ''
            set -e
            export NIX_STATE_DIR=$TMPDIR/state NIX_STORE_DIR=$TMPDIR/store
            cp --no-preserve=mode -rT $files .
            nix --extra-experimental-features nix-command eval --json -f .sops.nix | yq e -P - > .sops.yaml
            diff -u $files/.sops.yaml .sops.yaml
            fd -e yaml -x sops updatekeys --yes {}
            touch $out
          '';
    };
}
