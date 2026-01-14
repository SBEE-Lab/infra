{ config, ... }:
{
  security.acme = {
    defaults.email = "sjang.bioe@gmail.com";
    acceptTerms = true;

    certs = {
      "minio.sjanglab.org" = {
        dnsProvider = "cloudflare";
        environmentFile = config.sops.secrets.cloudflare-credentials.path;
        webroot = null;
      };
    };
  };

  services.nginx.enable = true;

  sops.secrets.cloudflare-credentials = {
    sopsFile = ./secrets.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };
}
