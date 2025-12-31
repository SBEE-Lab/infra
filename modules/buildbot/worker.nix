# Buildbot Worker (deployed on psi)
{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (config.networking.sbee) hosts;
  deploy-rs-pkg = inputs.deploy-rs.packages.${pkgs.system}.deploy-rs;
  sshPort = 10022;
in {
  imports = [inputs.buildbot-nix.nixosModules.buildbot-worker];

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.sops.secrets.buildbot-worker-password.path;
    masterUrl = "tcp:host=${hosts.psi.wg-serv}:port=9989";
  };

  nix.settings.trusted-users = ["buildbot-worker"];

  systemd.services.buildbot-worker.path = [
    deploy-rs-pkg
  ];

  # SSH client config for buildbot-worker deploy
  # Only applies when buildbot-worker user SSHs to managed hosts
  programs.ssh.extraConfig = ''
    Match LocalUser buildbot-worker Host eta,rho,tau,psi
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
