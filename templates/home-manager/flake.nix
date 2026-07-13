{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "git+https://github.com/SBEE-Lab/nixpkgs?shallow=1&ref=main";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    let
      # the system & architecture you use
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      username = "jdoe";
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
        extraSpecialArgs = {
          inherit username;
        };
      };
    };
}
