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

  # Public key for acme-sync from eta (generated with gen-acme-sync-key.sh)
  acmeSyncPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7mZ/UfOMpnrHaIigljsGWXCQAovWezdPpA3WQy1Qgu acme-sync@eta";
in
{
  # acme-sync user for receiving certificates from eta
  users.users.acme-sync = {
    isSystemUser = true;
    group = "acme-sync";
    home = certDir;
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ acmeSyncPubKey ];
  };
  users.groups.acme-sync.members = [ "nginx" ];

  # Create certificate directory owned by acme-sync
  systemd.tmpfiles.rules = [
    "d ${certDir} 0750 acme-sync acme-sync - -"
  ];

  # Reload nginx when certificates are updated
  systemd.services.acme-sync-reload-nginx = {
    description = "Reload nginx after certificate sync";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reload nginx";
    };
  };
  systemd.paths.acme-sync-watch = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = "${certDir}/fullchain.pem";
      Unit = "acme-sync-reload-nginx.service";
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
