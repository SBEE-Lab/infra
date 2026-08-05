{
  config,
  inputs,
  ...
}:
let
  domain = "mq.sjanglab.org";
  port = 18980;

  githubAppId = 4495517;
in
{
  imports = [
    inputs.gitea-mq.nixosModules.default
    ../acme
    ../gatus/check.nix
  ];

  gatusCheck.pull = [
    {
      name = "Merge queue";
      url = "https://${domain}/healthz";
      group = "ci";
    }
  ];

  services.postgresql.ensureDatabases = [ "gitea-mq" ];
  services.postgresql.ensureUsers = [
    {
      name = "gitea-mq";
      ensureDBOwnership = true;
    }
  ];

  services.gitea-mq = {
    enable = true;
    listenAddr = "127.0.0.1:${toString port}";
    externalUrl = "https://${domain}";
    hideRefFromClients = false;
    batchMax = 5;
    github = {
      appId = githubAppId;
      privateKeyFile = config.sops.secrets.gitea-mq-github-private-key.path;
      webhookSecretFile = config.sops.secrets.gitea-mq-github-webhook-secret.path;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
    group = "nginx";
  };

  sops.secrets = {
    gitea-mq-github-private-key = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };
    gitea-mq-github-webhook-secret = {
      sopsFile = ./secrets.yaml;
      mode = "0400";
    };
  };
}
