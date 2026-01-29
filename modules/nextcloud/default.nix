{
  config,
  pkgs,
  ...
}:
let
  inherit (config.networking.sbee) hosts;
  domain = "cloud.sbee.lab";
in
{
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
        ;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
    };
  };

  # Nginx with self-signed certificate
  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/nextcloud/ssl/cert.pem";
      sslCertificateKey = "/var/lib/nextcloud/ssl/key.pem";
    };
  };

  # Generate self-signed certificate on activation
  systemd.services.nextcloud-ssl-cert = {
    description = "Generate self-signed SSL certificate for Nextcloud";
    wantedBy = [ "multi-user.target" ];
    before = [ "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/nextcloud/ssl
      if [ ! -f /var/lib/nextcloud/ssl/cert.pem ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 3650 \
          -newkey rsa:2048 \
          -keyout /var/lib/nextcloud/ssl/key.pem \
          -out /var/lib/nextcloud/ssl/cert.pem \
          -subj "/CN=${domain}"
        chown -R nginx:nginx /var/lib/nextcloud/ssl
        chmod 600 /var/lib/nextcloud/ssl/key.pem
      fi
    '';
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
