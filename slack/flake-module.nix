_: {
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.slack-deploy = pkgs.mkShellNoCC {
        packages = [
          config.packages.slack-cli
          pkgs.jq
        ];
      };
    };
}
