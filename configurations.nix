{
  self,
  inputs,
  ...
}:
let
  inherit (inputs)
    nixpkgs
    authentik-nix
    disko
    sops-nix
    srvos
    ;

  system = "x86_64-linux";

  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = import ./overlays { inherit inputs; };
  };

  # CUDA-enabled pkgs for GPU hosts (psi)
  pkgsCuda = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
    };
    overlays = import ./overlays { inherit inputs; };
  };

  nixosSystem =
    {
      modules,
      useCuda ? false,
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self inputs; };
      modules = modules ++ [ { nixpkgs.pkgs = if useCuda then pkgsCuda else pkgs; } ];
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
    ./modules/users/admins.nix
    ./modules/users/extra-user-options.nix
    ./modules/zram.nix

    disko.nixosModules.disko
    srvos.nixosModules.server
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
      }:
      let
        sopsFile = ./. + "/hosts/${config.networking.hostName}.yaml";
      in
      {
        users.withSops = builtins.pathExists sopsFile;
        sops.secrets = lib.mkIf config.users.withSops {
          root-password-hash.neededForUsers = true;
        };
        sops.defaultSopsFile = lib.mkIf (builtins.pathExists sopsFile) sopsFile;
        time.timeZone = lib.mkForce "Asia/Seoul";
      }
    )
  ];

  computeModules = commonModules ++ [
    ./modules/project-space.nix
    ./modules/workspace-space.nix
    ./modules/blobs-space.nix
    ./modules/nix-ld.nix
    ./modules/icebox
  ];
in
{
  flake.nixosConfigurations = {
    psi = nixosSystem {
      modules = computeModules ++ [ ./hosts/psi.nix ];
      useCuda = true;
    };
    rho = nixosSystem { modules = commonModules ++ [ ./hosts/rho.nix ]; };
    tau = nixosSystem { modules = commonModules ++ [ ./hosts/tau.nix ]; };
    eta = nixosSystem {
      modules = commonModules ++ [
        authentik-nix.nixosModules.default
        ./hosts/eta.nix
      ];
    };
  };
}
