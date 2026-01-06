# https://github.com/nix-community/infra/tree/e25c9f72a56641d5b4646d2711e59ccc63e171b8/dev/terraform.nix
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      devShells.terraform = pkgs.mkShellNoCC {
        packages = [
          pkgs.sops
          pkgs.terragrunt
          pkgs.postgresql_17
          pkgs.vultr-cli
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
        ]);
      };
    };
}
