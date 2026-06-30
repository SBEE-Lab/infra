{ config, ... }:
{
  security.acme = {
    defaults.email = "sjang.bioe@gmail.com";
    acceptTerms = true;

    certs = {
      "cloud.sjanglab.org" = {
        dnsProvider = "cloudflare";
        environmentFile = config.sops.secrets.cloudflare-credentials.path;
        webroot = null;
        group = "nginx"; # Allow nginx to read certs
      };
      "docling.sjanglab.org" = {
        dnsProvider = "cloudflare";
        environmentFile = config.sops.secrets.cloudflare-credentials.path;
        webroot = null;
        group = "nginx";
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
