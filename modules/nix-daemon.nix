# https://github.com/nix-community/infra/blob/d886971901070f0d1f5265cef08582051c856e7d/modules/shared/nix-daemon.nix
{lib, ...}: let
  asGB = size: toString (size * 1024 * 1024 * 1024);
  inherit (lib) mkDefault;
in {
  nix = {
    gc.automatic = mkDefault true;
    gc.dates = mkDefault "monthly";
    gc.options = mkDefault "--delete-older-than 14d";
    gc.randomizedDelaySec = "1h";

    settings = {
      trusted-substituters = ["http://10.200.0.2:5000"];

      substituters = [
        "http://10.200.0.2:5000"
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];

      trusted-public-keys = [
        "cache.sjanglab.org-1:qnmAmr3qctcLiatkrtYX3OpvFKP4Z9whK8pLtSdCgPw="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
}
