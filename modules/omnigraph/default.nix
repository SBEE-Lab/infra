{
  lib,
  pkgs,
  self,
  ...
}:
{
  imports = [
    ./options.nix
    ./config.nix
  ];

  services.omnigraph.package =
    lib.mkDefault
      self.packages.${pkgs.stdenv.hostPlatform.system}.omnigraph-server;
}
