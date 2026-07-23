{
  description = "SBEE laboratory infrastructures flake";

  inputs = {
    # Shared roots. Other flakes follow these to avoid duplicate lock nodes.
    nixpkgs.url = "git+https://github.com/SBEE-Lab/nixpkgs?shallow=1&ref=main";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Core modules and system integrations.
    authentik-nix = {
      url = "github:nix-community/authentik-nix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixbot = {
      url = "github:Mic92/nixbot";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fast-nix-gc = {
      url = "github:Mic92/fast-nix-gc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-images = {
      url = "github:nix-community/nixos-images";
      inputs.nixos-stable.follows = "nixpkgs";
      inputs.nixos-unstable.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Applications.
    rag-nix = {
      url = "github:mulatta/rag.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    multievolve-nix = {
      url = "github:mulatta/multievolve-nix/nixos-module-service";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    niks3 = {
      url = "github:Mic92/niks3";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    rustfs = {
      url = "github:rustfs/rustfs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rhwp-nextcloud = {
      url = "github:mulatta/rhwp-nextcloud";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      imports = [
        inputs.treefmt-nix.flakeModule
        ./lib/flake-module.nix
        ./configurations.nix
        ./checks/flake-module.nix
        ./docs/flake-module.nix
        ./packages/flake-module.nix
        ./templates/flake-module.nix
        ./terraform/flake-module.nix
        ./modules/monitoring/alerts/flake-module.nix
      ];
      perSystem =
        { system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            localSystem.system = system;
          };
        in
        {
          _module.args.pkgs = pkgs;

          treefmt = {
            projectRootFile = "flake.nix";

            programs = {
              # Nix formatters & linters
              nixfmt.enable = true;
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

              # Markdown formatter (docs/ only)
              mdformat = {
                enable = true;
                includes = [ "docs/**/*.md" ];
              };

              # Other formatters
              keep-sorted.enable = true;
              yamlfmt.enable = true;
              taplo.enable = true;
            };

            settings.formatter =
              let
                nixExcludes = [
                  "*.lock"
                  "*/secrets.yaml"
                  "hosts/**.yaml"
                  "modules/users/admins.nix"
                  "modules/users/researchers.nix"
                  "modules/users/students.nix"
                ];
              in
              {
                deadnix.excludes = nixExcludes;
                statix.excludes = nixExcludes;
              };

            settings.global.excludes = [
              "hosts/**.yaml"
              "*/secrets.yaml"
              "*/secrets.yml"
              "*.lock"
              ".gitignore"
            ];
          };

          devShells.default = pkgs.mkShellNoCC {
            buildInputs = with pkgs; [
              # deploy tools
              python3.pkgs.invoke
              python3.pkgs.deploykit
              python3.pkgs.bcrypt

              # nix tools
              nixVersions.latest
              nixos-rebuild
              nixos-anywhere

              # basic tools
              gitMinimal
              coreutils
              findutils
              rsync
              yq-go
              fd

              # secret tools
              openssh
              sops
              ssh-to-age
              age
              mkpasswd

              # network tools
              dnsmasq
              wireguard-tools

              # docs tools
              zensical
            ];
          };
        };
    };
}
