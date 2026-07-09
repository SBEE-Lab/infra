{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sjanglab.org";
  collaboraPort = 9980;
  whiteboardPort = 3002;
  certDir = "/var/lib/acme/${domain}";
  oidcProvider = {
    identifier = "authentik";
    clientId = "4GdFUqIaLHa3Hx5VnMul6RU8iaJG8GqtUHXHjfqo";
    discoveryUri = "https://auth.sjanglab.org/application/o/nextcloud/.well-known/openid-configuration";
    scope = "openid email profile groups";
    mappingUid = "email";
    mappingGroups = "groups";
    mappingQuota = "quota";
    extraClaims = "nextcloud-groups";
  };
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "Nextcloud";
      group = "apps";
      url = "https://cloud.sjanglab.org/status.php";
    }
  ];

  acmeSyncer.mkReceiver = [
    { inherit domain; }
  ];

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = domain;
    https = true;

    database.createLocally = false;
    config = {
      dbtype = "pgsql";
      dbhost = "${hosts.rho.wg-admin}:5432";
      dbname = "nextcloud";
      dbuser = "nextcloud";
      dbpassFile = config.sops.secrets.nextcloud-db-password.path;
      adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
      adminuser = "admin";
    };

    settings = {
      trusted_proxies = [ "127.0.0.1" ];
      overwriteprotocol = "https";
      allow_local_remote_servers = true; # authentik is on local network
      default_phone_region = "KR";
      maintenance_window_start = 1; # 1:00 UTC = 10:00 KST

      # user_oidc: fetch claims from userinfo endpoint (not just id_token)
      # Required because Authentik Property Mapping only applies to userinfo
      user_oidc.enrich_login_id_token_with_userinfo = true;
      loglevel = 1;
    };

    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit
        user_oidc
        calendar
        tasks
        whiteboard
        richdocuments
        groupfolders
        ;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
    };
  };

  # Whiteboard real-time collaboration server
  services.nextcloud-whiteboard-server = {
    enable = true;
    settings = {
      NEXTCLOUD_URL = "https://${domain}";
    };
    secrets = [ config.sops.secrets.whiteboard-jwt.path ];
  };

  # Collabora Online for document editing
  services.collabora-online = {
    enable = true;
    port = collaboraPort;
    settings = {
      # Public URL for discovery/browser access
      server_name = domain;
      # Allow Nextcloud to connect
      storage.wopi."@allow" = true;
      # Disable SSL termination (nginx handles it)
      ssl = {
        enable = false;
        termination = true;
      };
      # Allow same-host connections
      net.post_allow.host = [
        "127\\.0\\.0\\.1"
        "::1"
      ];
    };
    aliasGroups = [
      {
        host = "https://${domain}:443";
      }
    ];
  };

  # Nginx with certificate from eta (synced via rsync)
  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "${certDir}/fullchain.pem";
      sslCertificateKey = "${certDir}/key.pem";
      extraConfig = ''
        access_log /var/log/nginx/access-audit/nextcloud.log nginx_access_json;
      '';

      # Collabora Online proxy paths
      locations = {
        # Static files
        "^~ /browser" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
          proxyWebsockets = true;
        };
        # WOPI discovery and capabilities
        "^~ /hosting/discovery" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
        };
        "^~ /hosting/capabilities" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
        };
        # All Collabora /cool/ paths including WebSocket (/cool/*/ws)
        # Must use ^~ to prevent Nextcloud's static file regex from intercepting
        "^~ /cool/" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
          proxyWebsockets = true;
        };
        # Whiteboard WebSocket server
        "/whiteboard/" = {
          proxyPass = "http://127.0.0.1:${toString whiteboardPort}/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header Host $host;
          '';
        };
      };
    };
  };

  sops.secrets.nextcloud-db-password = {
    sopsFile = ./secrets.yaml;
    owner = "nextcloud";
    group = "nextcloud";
  };
  sops.secrets.nextcloud-admin-password = {
    sopsFile = ./secrets.yaml;
    owner = "nextcloud";
    group = "nextcloud";
  };
  sops.secrets.whiteboard-jwt = {
    sopsFile = ./secrets.yaml;
  };
  sops.secrets.nextcloud-oidc-client-secret = {
    sopsFile = ../../terraform/authentik/oidc-secrets.yaml;
    key = "NEXTCLOUD_CLIENT_SECRET";
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0400";
    restartUnits = [ "nextcloud-oidc-authentik.service" ];
  };

  systemd.services.nextcloud-oidc-authentik = {
    description = "Configure Authentik OIDC provider for Nextcloud";
    wantedBy = [ "multi-user.target" ];
    requires = [ "nextcloud-setup.service" ];
    after = [ "nextcloud-setup.service" ];
    # Authentik's OAuth2 client is managed by Terraform; the Nextcloud-side
    # user_oidc provider lives in Nextcloud's database and must be reconciled via occ.
    restartTriggers = [ (builtins.toJSON oidcProvider) ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe config.services.nextcloud.occ} user_oidc:provider ${oidcProvider.identifier} \
        --clientid=${oidcProvider.clientId} \
        --clientsecret-file=${config.sops.secrets.nextcloud-oidc-client-secret.path} \
        --discoveryuri=${oidcProvider.discoveryUri} \
        --scope="${oidcProvider.scope}" \
        --mapping-uid=${oidcProvider.mappingUid} \
        --mapping-groups=${oidcProvider.mappingGroups} \
        --mapping-quota=${oidcProvider.mappingQuota} \
        --extra-claims=${oidcProvider.extraClaims} \
        --group-provisioning=1 \
        --send-id-token-hint=1
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
