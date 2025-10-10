{
  self,
  inputs,
  ...
}: let
  inherit
    (inputs)
    nixpkgs
    disko
    sops-nix
    srvos
    ;

  nixosSystem = args:
    nixpkgs.lib.nixosSystem (
      {
        specialArgs = {inherit self inputs;};
      }
      // args
    );

  pkgsForSystem = system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [self.overlays.default];
    };
  pkgs-x86_64-linux = pkgsForSystem "x86_64-linux";
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
        # TODO: share nixpkgs for each machine to speed up local evaluation.
        #nixpkgs.pkgs = self.inputs.nixpkgs.legacyPackages.${system};

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
      ./modules/bioinformatics
      ./modules/scratch-space.nix
    ];
in {
  flake.nixosConfigurations = {
    psi = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = computeModules ++ [./hosts/psi.nix];
    };
    rho = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = computeModules ++ [./hosts/rho.nix];
    };
    tau = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = computeModules ++ [./hosts/tau.nix];
    };
    eta = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = commonModules ++ [./hosts/eta.nix];
    };
    turing = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = commonModules ++ [./hosts/turing.nix];
    };
  };
}
