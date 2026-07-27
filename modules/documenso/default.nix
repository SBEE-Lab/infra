{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  domain = "documenso.sjanglab.org";
  port = 3000;
  certDir = "/var/lib/acme/${domain}";
  databaseUrl = "postgres://documenso:$DB_PASSWORD@${hosts.rho.wg-admin}:5432/documenso";
  startDocumenso = pkgs.writeShellApplication {
    name = "start-documenso";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      DB_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/db-password")
      export NEXTAUTH_SECRET
      NEXTAUTH_SECRET=$(cat "$CREDENTIALS_DIRECTORY/nextauth-secret")
      export NEXT_PRIVATE_ENCRYPTION_KEY
      NEXT_PRIVATE_ENCRYPTION_KEY=$(cat "$CREDENTIALS_DIRECTORY/encryption-key")
      export NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY
      NEXT_PRIVATE_ENCRYPTION_SECONDARY_KEY=$(cat "$CREDENTIALS_DIRECTORY/encryption-secondary-key")
      export NEXT_PRIVATE_OIDC_CLIENT_SECRET
      NEXT_PRIVATE_OIDC_CLIENT_SECRET=$(cat "$CREDENTIALS_DIRECTORY/oidc-client-secret")

      export NEXT_PRIVATE_DATABASE_URL="${databaseUrl}"
      export NEXT_PRIVATE_DIRECT_DATABASE_URL="${databaseUrl}"

      exec ${lib.getExe pkgs.documenso}
    '';
  };
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Documenso";
      group = "apps";
      url = "https://${domain}";
    }
  ];

  acmeSyncer.mkReceiver = [
    {
      inherit domain;
      user = "acme-sync-documenso";
    }
  ];

  users.users.documenso = {
    isSystemUser = true;
    group = "documenso";
    home = "/var/lib/documenso";
  };
  users.groups.documenso = { };

  systemd.services.documenso = {
    description = "Documenso";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      PORT = toString port;
      HOST = "127.0.0.1";
      NODE_ENV = "production";
      NEXT_PUBLIC_WEBAPP_URL = "https://${domain}";
      NEXT_PRIVATE_INTERNAL_WEBAPP_URL = "http://127.0.0.1:${toString port}";
      NEXT_PUBLIC_UPLOAD_TRANSPORT = "database";
      NEXT_PRIVATE_SIGNING_TRANSPORT = "local";
      NEXT_PRIVATE_JOBS_PROVIDER = "local";
      NEXT_PRIVATE_SMTP_FROM_NAME = "Documenso";
      NEXT_PRIVATE_SMTP_FROM_ADDRESS = "noreply@sjanglab.org";
      NEXT_PRIVATE_OIDC_WELL_KNOWN = "https://auth.sjanglab.org/application/o/documenso/.well-known/openid-configuration";
      NEXT_PRIVATE_OIDC_CLIENT_ID = "NJ46KMGddzOrzAwiNarftcidtl17wACc6c9AGEa8";
      NEXT_PRIVATE_OIDC_PROVIDER_LABEL = "Authentik";
      NEXT_PRIVATE_OIDC_SKIP_VERIFY = "true";
      NEXT_PUBLIC_DISABLE_EMAIL_PASSWORD_SIGNUP = "true";
      NEXT_PUBLIC_DISABLE_GOOGLE_SIGNUP = "true";
      NEXT_PUBLIC_DISABLE_MICROSOFT_SIGNUP = "true";
      NEXT_PUBLIC_FEATURE_BILLING_ENABLED = "false";
      DOCUMENSO_DISABLE_TELEMETRY = "true";
    };

    serviceConfig = {
      Type = "simple";
      User = "documenso";
      Group = "documenso";
      StateDirectory = "documenso";
      WorkingDirectory = "/var/lib/documenso";
      LoadCredential = [
        "db-password:${config.sops.secrets.documenso-db-password.path}"
        "nextauth-secret:${config.sops.secrets.documenso-nextauth-secret.path}"
        "encryption-key:${config.sops.secrets.documenso-encryption-key.path}"
        "encryption-secondary-key:${config.sops.secrets.documenso-encryption-secondary-key.path}"
        "oidc-client-secret:${config.sops.secrets.documenso-oidc-client-secret.path}"
      ];
      ExecStart = lib.getExe startDocumenso;
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/documenso" ];
    };
  };

  sops.secrets = {
    documenso-db-password = {
      sopsFile = ./secrets.yaml;
      owner = "documenso";
      group = "documenso";
    };
    documenso-nextauth-secret = {
      sopsFile = ./secrets.yaml;
      owner = "documenso";
      group = "documenso";
    };
    documenso-encryption-key = {
      sopsFile = ./secrets.yaml;
      owner = "documenso";
      group = "documenso";
    };
    documenso-encryption-secondary-key = {
      sopsFile = ./secrets.yaml;
      owner = "documenso";
      group = "documenso";
    };
    documenso-oidc-client-secret = {
      sopsFile = ../../terraform/authentik/oidc-secrets.yaml;
      key = "DOCUMENSO_CLIENT_SECRET";
      owner = "documenso";
      group = "documenso";
      restartUnits = [ "documenso.service" ];
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";
      extraConfig = ''
        access_log /var/log/nginx/access-audit/documenso.log nginx_access_json;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
