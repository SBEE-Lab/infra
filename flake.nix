{
  description = "SBEE laboratory infrastructures flake";
  nixConfig = {
    extra-substituters = ["https://cache.sjanglab.org/infra"];
    extra-trusted-public-keys = ["infra:I/HTgvj5en5tiRtunBNFLkthLFBu3Gz39OvYEss/Td4="];
  };
  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import inputs.systems;
      imports = [
        ./configurations.nix
        ./checks/flake-module.nix
        ./docs/flake-module.nix
        ./packages/flake-module.nix
        ./formatter/flake-module.nix
        ./shells/flake-module.nix
        ./terraform/flake-module.nix
      ];
      perSystem = {system, ...}: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = import ./overlays {inherit inputs;};
        };
      };
    };

  inputs = {
    # keep-sorted start
    attic.inputs.flake-compat.follows = "";
    attic.inputs.nixpkgs.follows = "nixpkgs";
    attic.url = "github:zhaofengli/attic";
    buildbot-nix.url = "github:nix-community/buildbot-nix";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixos-generators.inputs.nixlib.follows = "nixpkgs";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-images.inputs.nixos-unstable.follows = "nixpkgs-unstable";
    nixos-images.url = "github:nix-community/nixos-images";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.inputs.nixpkgs.follows = "nixpkgs";
    srvos.url = "github:nix-community/srvos";
    systems.url = "github:nix-systems/default";
    toolz.inputs.flake-parts.follows = "flake-parts";
    toolz.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    toolz.inputs.nixpkgs.follows = "nixpkgs";
    toolz.inputs.systems.follows = "systems";
    toolz.inputs.treefmt-nix.follows = "treefmt-nix";
    toolz.url = "github:zmblr/toolz/release-25.05";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };
}
