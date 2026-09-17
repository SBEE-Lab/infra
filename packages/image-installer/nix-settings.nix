# take from srvos
{ lib, ... }:
{
  nix.settings = {
    # Fallback quickly if substituters are not available.
    connect-timeout = 5;
    substituters = lib.mkAfter [ "https://cache.sjanglab.org" ];
    trusted-public-keys = lib.mkAfter [
      "cache.sjanglab.org-1:VzE09zCt/P+zsSqRq7nyIPVoQXdADRyRsoF1x25ul1U="
    ];
  };

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Avoid copying unnecessary stuff over SSH
  nix.settings.builders-use-substitutes = true;
}
