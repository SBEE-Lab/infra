# Hercules-style nixbot effects.
{ inputs, self }:
{ primaryRepo, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  docs = self.packages.x86_64-linux.docs;
  repoUrl = primaryRepo.remoteHttpUrl or "https://github.com/${primaryRepo.name}";
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

          token=$(jq -r '.git.data.token' "$HERCULES_CI_SECRETS_JSON")
          remote=$(printf '%s' ${lib.escapeShellArg repoUrl} \
            | sed "s#https://#https://x-access-token:$token@#")

          git config --global user.email "nixbot@users.noreply.github.com"
          git config --global user.name "nixbot"

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
}
