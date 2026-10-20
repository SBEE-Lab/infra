# https://github.com/nix-community/infra/tree/e25c9f72a56641d5b4646d2711e59ccc63e171b8/dev/terraform.nix
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      authentikProvider = pkgs.terraform-providers.mkProvider {
        owner = "goauthentik";
        repo = "terraform-provider-authentik";
        rev = "v2026.5.0";
        hash = "sha256-S7TbUK68XAGwdjkoRko8cZyA1UsuKTjR9jxh+YsjMyo=";
        vendorHash = "sha256-6PjmKg9cpBjx2Pn92Jm7fIp/35erbS/AeQ3NB2VmFlQ=";
        spdx = "GPL-3.0-only";
        homepage = "https://registry.terraform.io/providers/goauthentik/authentik";
      };

      headscaleProvider = pkgs.terraform-providers.mkProvider {
        owner = "awlsring";
        repo = "terraform-provider-headscale";
        rev = "v0.5.1";
        hash = "sha256-TgDwX5On4nvPU2hAePPimZD2f3y2ev3nKVmkRaXiTxk=";
        vendorHash = "sha256-zkV47RZtjjaIy+9sLpCgfcnYqWTSgKqdgHZhJ26oaQQ=";
        spdx = "MPL-2.0";
        homepage = "https://registry.terraform.io/providers/awlsring/headscale";
      };

      healthchecksioProvider = pkgs.terraform-providers.mkProvider {
        owner = "kristofferahl";
        repo = "terraform-provider-healthchecksio";
        rev = "v2.3.0";
        hash = "sha256-mR4mJiXF3YFY0DG9M9EjuR+V1cNTfvbY1gPL5A+V9T0=";
        vendorHash = "sha256-NauILuu4noOVZIBRfueFBx5Mx2sl7GGzyhL7254MndY=";
        spdx = "Apache-2.0";
        homepage = "https://registry.terraform.io/providers/kristofferahl/healthchecksio";
      };
    in
    {
      devShells.terraform = pkgs.mkShellNoCC {
        # Keep direnv and non-interactive commands on the same Nix provider set.
        TG_NON_INTERACTIVE = "true";
        TG_NO_AUTO_PROVIDER_CACHE_DIR = "1";
        TG_PROVIDER_CACHE = "false";
        TG_NO_AUTO_INIT = "false";
        INFRA_TERRAFORM_CACHE_KEY = builtins.baseNameOf config.packages.terraform;
        INFRA_TERRAFORM_GUARD = "${pkgs.writeShellScript "terraform-environment-guard" ''
          set -eu
          if [ "''${TG_TF_PATH:-}" != "${config.packages.terraform}/bin/tofu" ] ||
             [ ! -x "${config.packages.terraform}/bin/tofu" ]; then
            echo 'Use the Terraform devshell without overriding TG_TF_PATH.' >&2
            exit 1
          fi
          if [ -n "''${TF_PLUGIN_CACHE_DIR:-}" ] ||
             [ -n "''${TF_CLI_CONFIG_FILE:-}" ] ||
             [ "''${TG_PROVIDER_CACHE:-}" != false ] ||
             [ "''${TG_NO_AUTO_PROVIDER_CACHE_DIR:-}" != 1 ]; then
            echo 'External provider caches or CLI configuration are not supported.' >&2
            exit 1
          fi
          if [ "''${TG_NO_AUTO_INIT:-}" != false ] ||
             [ "''${INFRA_TERRAFORM_CACHE_KEY:-}" != "${builtins.baseNameOf config.packages.terraform}" ] ||
             [ -n "''${TG_DOWNLOAD_DIR:-}" ] ||
             [ -n "''${TF_DATA_DIR:-}" ]; then
            echo 'Use automatic init and the Nix-specific Terragrunt cache without overrides.' >&2
            exit 1
          fi
        ''}";

        packages = [
          pkgs.curl
          pkgs.jq
          pkgs.shellcheck
          pkgs.sops
          pkgs.terragrunt
          pkgs.vultr-cli
          pkgs.yq-go
          config.packages.terraform
        ];

        TG_TF_PATH = "${config.packages.terraform}/bin/tofu";
        TERRAGRUNT_TFPATH = "${config.packages.terraform}/bin/tofu";
      };
      packages = {
        terraform = pkgs.opentofu.withPlugins (p: [
          p.integrations_github
          p.vultr_vultr
          p.hashicorp_external
          p.carlpett_sops
          p.hashicorp_local
          p.hashicorp_null
          p.cloudflare_cloudflare
          authentikProvider
          headscaleProvider
          healthchecksioProvider
        ]);
      };
    };
}
