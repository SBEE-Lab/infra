{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.biodb;
  helper = import ./helper-package.nix { inherit pkgs; };
  compiled = import ./compiler.nix {
    inherit
      cfg
      helper
      lib
      pkgs
      ;
  };
in
{
  options.services.biodb = import ./options.nix { inherit lib; };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = compiled.systemPackages;

    systemd.tmpfiles.rules = [
      "d ${cfg.root} 0755 root users -"
    ]
    ++ lib.mapAttrsToList (
      name: db:
      "d ${cfg.root}/${name}${
        lib.optionalString (db.syncSubdir != "") "/${db.syncSubdir}"
      } 0755 root users -"
    ) compiled.enabledDatabases;

    systemd.services = compiled.services;
    systemd.timers = compiled.timers;
  };
}
