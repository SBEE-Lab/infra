# Buildbot Worker (deployed on psi)
{
  config,
  inputs,
  pkgs,
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
    masterUrl = "tcp:host=${hosts.psi.wg-admin}:port=9989";
  };

  systemd.services.buildbot-worker.path = [
    inputs.niks3.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  nix.settings.trusted-users = [ "buildbot-worker" ];

  sops.secrets = {
    buildbot-worker-password = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
  };
}
