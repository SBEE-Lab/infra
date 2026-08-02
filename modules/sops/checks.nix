# https://github.com/nix-community/infra/tree/e25c9f72a56641d5b4646d2711e59ccc63e171b8/dev/sops.nix
{ self, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      secretFilesByHost = lib.mapAttrs (
        _: nixos:
        lib.unique (lib.mapAttrsToList (_: secret: toString secret.sopsFile) nixos.config.sops.secrets)
      ) self.nixosConfigurations;
      secretFilesByHostJson = pkgs.writeText "sops-secret-files-by-host.json" (
        builtins.toJSON secretFilesByHost
      );
    in
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
              jq
              python3
            ];
            files = pkgs.lib.fileset.toSource {
              root = ../..;
              fileset = pkgs.lib.fileset.unions [
                (pkgs.lib.fileset.fromSource (pkgs.lib.sources.sourceFilesBySuffices ../.. [ ".yaml" ]))
                ../../hosts
                ../../.sops.nix
                ../../pubkeys.json
                ../../modules
              ];
            };
          }
          ''
            set -e
            export NIX_STATE_DIR=$TMPDIR/state NIX_STORE_DIR=$TMPDIR/store
            cp --no-preserve=mode -rT $files .
            nix --extra-experimental-features nix-command eval --json -f .sops.nix | yq e -P - > .sops.yaml
            diff -u $files/.sops.yaml .sops.yaml

            yq -o=json . .sops.yaml > rules.json
            python3 - ${secretFilesByHostJson} pubkeys.json rules.json <<'PY'
            import json
            import re
            import sys

            secret_files_by_host = json.load(open(sys.argv[1]))
            machine_keys = json.load(open(sys.argv[2]))["machines"]
            rules = json.load(open(sys.argv[3]))["creation_rules"]
            failures = []

            for host, secret_files in secret_files_by_host.items():
                recipient = machine_keys[host]
                for secret_file in secret_files:
                    relative_path = re.sub(
                        r"^/nix/store/[a-z0-9]+-source/", "", secret_file
                    )
                    rule = next(
                        (
                            rule
                            for rule in rules
                            if re.search(rule["path_regex"], relative_path)
                        ),
                        None,
                    )
                    recipients = (
                        set()
                        if rule is None
                        else {
                            age_recipient
                            for group in rule.get("key_groups", [])
                            for age_recipient in group.get("age", [])
                        }
                    )
                    if recipient not in recipients:
                        failures.append((host, relative_path))

            if failures:
                for host, secret_file in failures:
                    print(
                        f"missing SOPS recipient: host={host} file={secret_file}",
                        file=sys.stderr,
                    )
                raise SystemExit(1)
            PY

            fd -e yaml -x sops updatekeys --yes {}
            touch $out
          '';
    };
}
