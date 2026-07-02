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
    in
    {
      devShells.terraform = pkgs.mkShellNoCC {
        packages = [
          pkgs.curl
          pkgs.jq
          pkgs.shellcheck
          pkgs.sops
          pkgs.terragrunt
          pkgs.postgresql_17
          pkgs.vultr-cli
          pkgs.yq-go
          config.packages.terraform
        ];

        PGHOST = "localhost";
        PGPORT = "15432";
        PGUSER = "terraform";
        PGDATABASE = "terraform";
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
        ]);
      };
    };
}
