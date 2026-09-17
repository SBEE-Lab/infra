{ lib, pkgs, ... }:
let
  fontConfig = import ./font-config.nix { inherit lib pkgs; };
in
{
  systemd.services = {
    coolwsd-systemplate-setup.path = [ pkgs.cpio ];

    coolwsd = {
      environment.FONTCONFIG_FILE = fontConfig.file;
      restartTriggers = [ fontConfig.file ];
    };
  };
}
