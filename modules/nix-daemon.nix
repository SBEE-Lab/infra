# https://github.com/nix-community/infra/blob/d886971901070f0d1f5265cef08582051c856e7d/modules/shared/nix-daemon.nix
{ lib, ... }:
let
  asGB = size: toString (size * 1024 * 1024 * 1024);
  inherit (lib) mkDefault mkForce;
in
{
  services.fast-nix-gc = {
    enable = mkDefault true;
    automatic = mkDefault true;
    dates = mkDefault "03:15";
    deleteOlderThan = mkDefault "14d";
  };

  services.fast-nix-optimise = {
    enable = mkDefault true;
    automatic = mkDefault true;
    dates = mkDefault "04:15";
  };

  nix = {
    # fast-nix-gc and fast-nix-optimise take the same gc.lock; keep stock
    # timers off so srvos/nixpkgs do not run slower duplicate jobs.
    gc.automatic = mkForce false;
    optimise.automatic = mkForce false;

    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "http://10.100.0.2:5000"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.sjanglab.org:aSIxtSeiVTNYkl3ChoLs7amf0nIJNAuH0u0ikk3LZZo="
      ];

      system-features = [
        "benchmark"
        "big-parallel"
        "ca-derivations"
        "kvm"
        "nixos-test"
        "recursive-nix"
        "uid-range"
      ];

      # auto-free the /nix/store
      min-free = asGB 10;
      max-free = asGB 50;

      # Hard-link duplicated files
      auto-optimise-store = true;
    };
  };
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
