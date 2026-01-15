# Buildbot Worker (deployed on psi)
{
  config,
  inputs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
in
{
  imports = [ inputs.buildbot-nix.nixosModules.buildbot-worker ];

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.sops.secrets.buildbot-worker-password.path;
    masterUrl = "tcp:host=${hosts.psi.wg-serv}:port=9989";
  };

  nix.settings.trusted-users = [ "buildbot-worker" ];

  sops.secrets = {
    buildbot-worker-password = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
  };
}
