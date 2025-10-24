{
  self,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs disko sops-nix srvos;

  system = "x86_64-linux";

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = import ./overlays {inherit inputs;};
  };

  nixosSystem = modules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit self inputs;};
      modules = modules ++ [{nixpkgs.pkgs = pkgs;}];
    };

  commonModules = [
    ./modules/users/admins.nix
    ./modules/users/extra-user-options.nix
    ./modules/nix-daemon.nix
    ./modules/nix-index.nix
    ./modules/hosts.nix
    ./modules/cleanup-usr.nix
    ./modules/sshd
    ./modules/network.nix
    ./modules/packages.nix
    ./modules/register-flake.nix
    ./modules/auto-upgrade.nix

    disko.nixosModules.disko
    srvos.nixosModules.server
    srvos.nixosModules.mixins-telegraf
    srvos.nixosModules.mixins-terminfo
    srvos.nixosModules.mixins-nix-experimental

    ./modules/users
    ./modules/bootloader.nix
    sops-nix.nixosModules.sops
    (
      {
        config,
        lib,
        ...
      }: let
        sopsFile = ./. + "/hosts/${config.networking.hostName}.yaml";
      in {
        users.withSops = builtins.pathExists sopsFile;
        sops.secrets = lib.mkIf config.users.withSops {
          root-password-hash.neededForUsers = true;
        };
        sops.defaultSopsFile = lib.mkIf (builtins.pathExists sopsFile) sopsFile;
        time.timeZone = lib.mkForce "Asia/Seoul";
      }
    )
  ];

  computeModules =
    commonModules
    ++ [
      ./modules/scratch-space.nix
      ./modules/apptainer.nix
      ./modules/nix-ld.nix
      ({pkgs, ...}: {
        environment.systemPackages = with pkgs; [
          blast
          nextflow
        ];
      })
    ];
in {
  flake.nixosConfigurations = {
    psi = nixosSystem (computeModules ++ [./hosts/psi.nix]);
    rho = nixosSystem (computeModules ++ [./hosts/rho.nix]);
    tau = nixosSystem (computeModules ++ [./hosts/tau.nix]);
    eta = nixosSystem (commonModules ++ [./hosts/eta.nix]);
  };
}
