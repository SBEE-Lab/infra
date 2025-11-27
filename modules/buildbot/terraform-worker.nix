# Buildbot Worker for Terraform jobs (deployed on rho)
{
  config,
  inputs,
  pkgs,
  ...
}: let
  inherit (config.networking.sbee) hosts;
in {
  imports = [inputs.buildbot-nix.nixosModules.buildbot-worker];

  services.buildbot-nix.worker = {
    enable = true;
    name = "rho-terraform";
    workers = 1;
    workerPasswordFile = config.sops.secrets.buildbot-rho-worker-password.path;
    masterUrl = "tcp:host=${hosts.psi.wg-serv}:port=9989";
  };

  environment.systemPackages = [
    inputs.self.packages.${pkgs.system}.terraform
    pkgs.terragrunt
  ];

  users.users.buildbot-worker.extraGroups = ["wheel"];

  sops.secrets = {
    buildbot-rho-worker-password = {
      sopsFile = ./secrets.yaml;
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
    terraform-vultr-token = {
      sopsFile = ../../terraform/vultr/secrets.yaml;
      key = "VULTR_API_TOKEN";
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
    terraform-github-token = {
      sopsFile = ../../terraform/github/secrets.yaml;
      key = "GITHUB_TOKEN";
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
    terraform-cloudflare-token = {
      sopsFile = ../../terraform/cloudflare/secrets.yaml;
      key = "CLOUDFLARE_API_TOKEN";
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
    terraform-cloudflare-zone-id = {
      sopsFile = ../../terraform/cloudflare/secrets.yaml;
      key = "CLOUDFLARE_ZONE_ID";
      owner = "buildbot-worker";
      group = "buildbot-worker";
    };
  };

  sops.templates."terraform-env" = {
    owner = "buildbot-worker";
    group = "buildbot-worker";
    mode = "0400";
    content = ''
      TF_VAR_use_sops=false
      VULTR_API_KEY=${config.sops.placeholder.terraform-vultr-token}
      GITHUB_TOKEN=${config.sops.placeholder.terraform-github-token}
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder.terraform-cloudflare-token}
      TF_VAR_cloudflare_zone_id=${config.sops.placeholder.terraform-cloudflare-zone-id}
    '';
  };

  systemd.services.buildbot-worker.serviceConfig.EnvironmentFile =
    config.sops.templates."terraform-env".path;
}
