_: {
  security.acme = {
    defaults.email = "sjang.bioe@gmail.com";
    acceptTerms = true;
  };

  sops.secrets.cloudflare-credentials = {
    sopsFile = ./secrets.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };
}
