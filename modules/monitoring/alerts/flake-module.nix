_: {
  perSystem =
    { pkgs, config, ... }:
    {
      devShells.slack-deploy = pkgs.mkShellNoCC {
        packages = [
          config.packages.slack-cli
          pkgs.jq
        ];
      };
    };
}
