{
  config,
  lib,
  ...
}:
let
  sopsFile = ../.. + "/hosts/${config.networking.hostName}.yaml";
in
{
  users.withSops = builtins.pathExists sopsFile;

  sops.defaultSopsFile = lib.mkIf (builtins.pathExists sopsFile) sopsFile;
  sops.secrets = lib.mkIf config.users.withSops {
    root-password-hash.neededForUsers = true;
  };
}
