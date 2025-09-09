# https://github.com/nix-community/infra/blob/d886971901070f0d1f5265cef08582051c856e7d/modules/shared/nix-daemon.nix
{ pkgs, ... }:
let
  asGB = size: toString (size * 1024 * 1024 * 1024);
in
{
  nix = {
    gc.automatic = pkgs.lib.mkDefault true;
    gc.dates = "";
    gc.options = pkgs.lib.mkDefault "--delete-older-than 14d";

    settings = {
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];

      system-features = [
        "big-parallel"
        "kvm"
        "nixos-test"
      ];

      # auto-free the /nix/store
      min-free = asGB 1;
      max-free = asGB 50;

      # Hard-link duplicated files
      auto-optimise-store = true;
    };
  };
}
