{
  description = "SBEE laboratory infrastructures flake";
  # nixConfig = {
  #   extra-substituters = [];
  #   extra-trusted-public-keys = [];
  # };
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        ./configurations.nix
        ./checks/flake-module.nix
        ./docs/flake-module.nix
        ./formatter/flake-module.nix
        ./packages/flake-module.nix
        ./shells/flake-module.nix
        ./terraform/flake-module.nix
      ];
    };

  inputs = {
    # keep-sorted start
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    harmonia.inputs.flake-parts.follows = "flake-parts";
    harmonia.inputs.nixpkgs.follows = "nixpkgs";
    harmonia.inputs.treefmt-nix.follows = "treefmt-nix";
    harmonia.url = "github:nix-community/harmonia/";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixos-generators.inputs.nixlib.follows = "nixpkgs";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
    srvos.inputs.nixpkgs.follows = "nixpkgs";
    srvos.url = "github:nix-community/srvos";
    systems.url = "github:nix-systems/default";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };
}
