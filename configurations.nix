{
  self,
  inputs,
  ...
}: let
  inherit (inputs) nixpkgs disko sops-nix srvos deploy-rs;

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
    ./modules/zram.nix

    disko.nixosModules.disko
    srvos.nixosModules.server
    srvos.nixosModules.mixins-terminfo
    srvos.nixosModules.mixins-nix-experimental

    ./modules/users
    ./modules/bootloader.nix
    ./modules/attic/client.nix
    sops-nix.nixosModules.sops
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
      ./modules/research-utility.nix
      ./modules/project-space.nix
      ./modules/workspace-space.nix
      ./modules/blobs-space.nix
      ./modules/nix-ld.nix
    ];
in {
  flake.nixosConfigurations = {
    psi = nixosSystem (computeModules ++ [./hosts/psi.nix]);
    rho = nixosSystem (commonModules ++ [./hosts/rho.nix]);
    tau = nixosSystem (commonModules ++ [./hosts/tau.nix]);
    eta = nixosSystem (commonModules ++ [./hosts/eta.nix]);
  };

  flake.deploy = {
    sshUser = "root";
    user = "root";
    remoteBuild = true;
    magicRollback = true;
    autoRollback = true;

    nodes =
      nixpkgs.lib.mapAttrs (name: config: {
        hostname = name;
        sshOpts = ["-p" "10022"];
        profiles.system.path = deploy-rs.lib.${system}.activate.nixos config;
      })
      self.nixosConfigurations;
  };

  # deploy-rs checks
  flake.checks.${system} =
    deploy-rs.lib.${system}.deployChecks self.deploy;
}
