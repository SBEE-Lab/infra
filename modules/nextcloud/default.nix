{
  config,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sjanglab.org";
  collaboraPort = 9980;
  certDir = "/var/lib/acme/${domain}";
in
{
  # Create acme user/group for certificate directory ownership
  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };
  users.groups.acme = { };

  # Create certificate directory
  systemd.tmpfiles.rules = [
    "d ${certDir} 0750 acme nginx - -"
  ];

  # Pull certificate from eta (runs daily and on boot)
  systemd.services.acme-pull-from-eta = {
    description = "Pull cloud.sjanglab.org certificate from eta";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "pull-cert-from-eta" ''
        ${pkgs.rsync}/bin/rsync -e "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new" \
          -avz --chmod=D750,F640 \
          root@eta:/var/lib/acme/${domain}/ \
          ${certDir}/
        chown -R acme:nginx ${certDir}
        ${pkgs.systemd}/bin/systemctl reload nginx || true
      '';
    };
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };
  systemd.timers.acme-pull-from-eta = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1d";
      RandomizedDelaySec = "1h";
    };
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
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
    };

    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit
        user_oidc
        calendar
        tasks
        whiteboard
        richdocuments
        ;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
    };
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
        # Main document handling endpoint (WebSocket)
        "~ ^/cool/(.*)/ws$" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
          proxyWebsockets = true;
        };
        # Admin and other cool paths
        "^~ /cool/" = {
          proxyPass = "http://127.0.0.1:${toString collaboraPort}";
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

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
