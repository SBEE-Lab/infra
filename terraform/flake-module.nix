# https://github.com/nix-community/infra/tree/e25c9f72a56641d5b4646d2711e59ccc63e171b8/dev/terraform.nix
{
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    minio-provider = pkgs.terraform_1.plugins.mkProvider rec {
      version = "3.6.5";
      owner = "aminueza";
      repo = "terraform-provider-minio";
      rev = "v${version}";
      hash = "sha256-+I1nTNxLVny0pgdMF7vXPC3WxkInSXnbeHcqgrWG55s=";
      provider-source-address = "registry.terraform.io/aminueza/minio";
      vendorHash = "sha256-QWBzQXx/dzWZr9dn3LHy8RIvZL1EA9xYqi7Ppzvju7g=";
      spdx = "AGPL-3.0-or-later";
    };
  in {
    devShells.terraform = pkgs.mkShellNoCC {
      packages = [
        pkgs.sops
        pkgs.terragrunt
        config.packages.terraform
      ];
    };
    packages = {
      terraform = pkgs.opentofu.withPlugins (p: [
        p.github
        p.vultr
        p.external
        p.sops
        p.local
        p.null
        p.cloudflare
        minio-provider
      ]);
    };
  };
}
