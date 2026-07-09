# Hercules-style nixbot effects.
{ inputs, self }:
{ primaryRepo, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  docs = self.packages.x86_64-linux.docs;
  repoName = primaryRepo.name or "SBEE-Lab/infra";
  repoUrl = primaryRepo.remoteHttpUrl or "https://github.com/${repoName}";

  mkRepoEffect =
    name: script:
    pkgs.runCommand "effect-${name}"
      {
        nativeBuildInputs = [
          pkgs.cacert
          pkgs.git
          pkgs.gh
          pkgs.jq
          pkgs.nix
          pkgs.openssh
        ];
        secretsMap = builtins.toJSON { git.type = "GitToken"; };
        HOME = "/build/home";
      }
      ''
        set -euo pipefail

        export NIX_CONFIG="experimental-features = nix-command flakes"
        mkdir -p "$HOME"

        token=$(jq -r '.git.data.token' "$HERCULES_CI_SECRETS_JSON")
        export GH_TOKEN="$token"
        remote=$(printf '%s' ${lib.escapeShellArg repoUrl} \
          | sed "s#https://#https://x-access-token:$token@#")

        git config --global user.email "254842320+sbee-flake-updater[bot]@users.noreply.github.com"
        git config --global user.name "sbee-flake-updater[bot]"
        git config --global safe.directory '*'

        git clone --recurse-submodules "$remote" repo
        cd repo
        ${script}
      '';
in
{
  onPush.default.outputs.effects = lib.optionalAttrs (primaryRepo.branch or null == "main") {
    docs-pages =
      pkgs.runCommand "effect-docs-pages"
        {
          nativeBuildInputs = [
            pkgs.cacert
            pkgs.coreutils
            pkgs.git
            pkgs.gnused
            pkgs.jq
            pkgs.openssh
          ];
          secretsMap = builtins.toJSON { git.type = "GitToken"; };
          HOME = "/build/home";
        }
        ''
          set -euo pipefail

          mkdir -p "$HOME"

          token=$(jq -r '.git.data.token' "$HERCULES_CI_SECRETS_JSON")
          remote=$(printf '%s' ${lib.escapeShellArg repoUrl} \
            | sed "s#https://#https://x-access-token:$token@#")

          git config --global user.email "254842320+sbee-flake-updater[bot]@users.noreply.github.com"
          git config --global user.name "sbee-flake-updater[bot]"

          work=$(mktemp -d)
          cp -r --no-preserve=mode,ownership ${docs}/. "$work/"
          touch "$work/.nojekyll"

          cd "$work"
          git init -q -b gh-pages
          git add -A
          git commit -q -m ${lib.escapeShellArg "Deploy docs for ${primaryRepo.rev}"}
          git push -f "$remote" gh-pages
        '';
  };

  onSchedule.update-packages = {
    when = {
      hour = 3;
      minute = 0;
    };
    outputs.effects.update-packages = mkRepoEffect "update-packages" ''
      nix run .#updater -- --pr
    '';
  };
}
