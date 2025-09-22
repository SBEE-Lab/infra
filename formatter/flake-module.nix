{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];
  perSystem = {
    treefmt = {
      # Used to find the project root
      projectRootFile = ".git/config";

      programs = {
        # Nix formatters & linters
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;

        # Python formatters & linters
        ruff-check.enable = true;
        ruff-format.enable = true;

        # Shell formatters & linter
        shellcheck.enable = true;
        shfmt.enable = true;

        # Infrastructure as Code
        terraform.enable = true;
        hclfmt.enable = true;

        # Other formatters
        keep-sorted.enable = true;
        typos.enable = true;
        yamlfmt.enable = true;
        taplo.enable = true;
      };

      settings.formatter = let
        nixExcludes = [
          "modules/users/researchers.nix"
          "modules/users/students.nix"
        ];
      in {
        deadnix.excludes = nixExcludes;
        statix.excludes = nixExcludes;
      };

      settings.global.excludes = [
        "*/secrets.yaml"
        "*/secrets.yml"
        "*.lock"
        ".gitignore"
      ];
    };
  };
}
