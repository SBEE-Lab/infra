# Buildbot Worker (deployed on psi)
{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (config.networking.sbee) hosts;
  colmena-pkg = inputs.colmena.packages.${pkgs.system}.colmena;
  sshPort = 10022;
in {
  imports = [inputs.buildbot-nix.nixosModules.buildbot-worker];

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.sops.secrets.buildbot-worker-password.path;
    masterUrl = "tcp:host=${hosts.psi.wg-serv}:port=9989";
  };

  systemd.services.buildbot-worker.path = [
    pkgs.attic-client
    colmena-pkg
  ];

  # SSH client config for buildbot-worker
  # Host key verification uses SSH CA (configured in modules/sshd)
  programs.ssh.extraConfig = ''
    Match User buildbot-worker
        IdentityFile /run/secrets/buildbot-deploy-key
        Port ${toString sshPort}
  '';

  sops.secrets = {
    buildbot-worker-password = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
    buildbot-deploy-key = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot-worker";
      group = "buildbot-worker";
      mode = "0400";
    };
  };
}
