{
  self,
  inputs,
  ...
}:
let
  inherit (inputs)
    nixpkgs
    disko
    sops-nix
    srvos
    ;

  nixosSystem =
    args:
    nixpkgs.lib.nixosSystem (
      {
        specialArgs = { inherit self inputs; };
      }
      // args
    );

  pkgsForSystem =
    system:
    import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  pkgs-x86_64-linux = pkgsForSystem "x86_64-linux";
  commonModules = [
    ./modules/users/admins.nix
    ./modules/users/extra-user-options.nix
    ./modules/nix-daemon.nix
    ./modules/hosts.nix
    ./modules/cleanup-usr.nix
    ./modules/disko-zfs.nix
    ./modules/sshd
    ./modules/network.nix
    ./modules/packages.nix

    disko.nixosModules.disko

    srvos.nixosModules.server

    srvos.nixosModules.mixins-telegraf
    srvos.nixosModules.mixins-terminfo
    srvos.nixosModules.mixins-nix-experimental

    ./modules/users
    ./modules/bootloader.nix
    srvos.nixosModules.mixins-latest-zfs-kernel
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
        # TODO: share nixpkgs for each machine to speed up local evaluation.
        #nixpkgs.pkgs = self.inputs.nixpkgs.legacyPackages.${system};

        users.withSops = builtins.pathExists sopsFile;
        sops.secrets = lib.mkIf config.users.withSops {
          root-password-hash.neededForUsers = true;
        };
        sops.defaultSopsFile = lib.mkIf (builtins.pathExists sopsFile) sopsFile;

        time.timeZone = lib.mkForce "KR";
      }
    )
  ];
in
{
  flake.nixosConfigurations = {
    psi = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = commonModules ++ [ ./hosts/psi.nix ];
    };
    rho = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = commonModules ++ [ ./hosts/rho.nix ];
    };
    tau = nixosSystem {
      pkgs = pkgs-x86_64-linux;
      modules = commonModules ++ [ ./hosts/tau.nix ];
    };
  };
}
