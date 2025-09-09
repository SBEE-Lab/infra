{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem = {
    treefmt = {
      # Used to find the project root
      projectRootFile = ".git/config";

      programs = {
        typos.enable = true;
        terraform.enable = true;
        deadnix.enable = true;
        nixfmt.enable = true;
        ruff-check.enable = true;
        ruff-format.enable = true;
        shfmt.enable = true;
        shellcheck.enable = true;
        statix.enable = true;
        keep-sorted.enable = true;
        yamlfmt.enable = true;
      };

      settings.formatter = {
        deadnix.excludes = [
          "modules/users/researchers.nix"
          "modules/users/students.nix"
        ];
        statix.excludes = [
          "modules/users/researchers.nix"
          "modules/users/students.nix"
        ];
        typos.excludes = [
          "packages/install-iso/secrets.yaml"
        ];
      };
    };
  };
}
