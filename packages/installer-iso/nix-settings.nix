# take from srvos
{
  # Fallback quickly if substituters are not available.
  nix.settings.connect-timeout = 5;

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Avoid copying unnecessary stuff over SSH
  nix.settings.builders-use-substitutes = true;
}
