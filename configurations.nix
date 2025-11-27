{
  self,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs attic disko sops-nix srvos;

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
    ./modules/auto-upgrade.nix
    ./modules/cleanup-usr.nix
    ./modules/hosts.nix
    ./modules/network.nix
    ./modules/nix-daemon.nix
    ./modules/nix-index.nix
    ./modules/packages.nix
    ./modules/register-flake.nix
    ./modules/sshd
    ./modules/tmux.nix
    ./modules/users/admins.nix
    ./modules/users/extra-user-options.nix

    disko.nixosModules.disko
    srvos.nixosModules.server
    srvos.nixosModules.mixins-telegraf
    srvos.nixosModules.mixins-terminfo
    srvos.nixosModules.mixins-nix-experimental

    ./modules/users
    ./modules/bootloader.nix
    sops-nix.nixosModules.sops
    ./modules/attic/client.nix
    (
      {
        config,
        lib,
        ...
      }: let
        sopsFile = ./. + "/hosts/${config.networking.hostName}.yaml";
        # Check if attic-token exists in the sops file
      in {
        users.withSops = builtins.pathExists sopsFile;
        sops.secrets = lib.mkIf config.users.withSops {
          root-password-hash.neededForUsers = true;
          # attic-token will be added per-host after running inv attic-generate-host-token
          attic-token = lib.mkIf config.services.attic-client.enable {};
        };
        sops.defaultSopsFile = lib.mkIf (builtins.pathExists sopsFile) sopsFile;
        time.timeZone = lib.mkForce "Asia/Seoul";

        services.attic-client.enable = true;
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
          stdenv.cc.cc.lib
          zlib
          libGL
          gcc
          pkg-config
          cargo
          rustc
          nodejs
        ];
      })
    ];
in {
  flake.nixosConfigurations = {
    psi = nixosSystem (computeModules ++ [./hosts/psi.nix]);
    rho = nixosSystem (computeModules ++ [./hosts/rho.nix]);
    tau = nixosSystem (computeModules ++ [./hosts/tau.nix]);
    eta = nixosSystem (commonModules ++ [attic.nixosModules.atticd ./hosts/eta.nix]);
  };
}
