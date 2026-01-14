{
  config,
  inputs,
  lib,
  ...
}:
let
  report = ../hosts + "/${config.networking.hostName}-facter.json";
in
{
  imports = [ inputs.nixos-facter-modules.nxiosModules.facter ];
  config = {
    facter.reportPath = lib.mkIf (builtins.pathExists report) report;
  };
}
