{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./acme
    ./gatus/check.nix
  ];

  gatusCheck.pull = [
    {
      name = "ntfy";
      url = "https://ntfy.sjanglab.org/v1/health";
      group = "infra";
    }
  ];

  services.ntfy-sh = {
    enable = true;
    package = pkgs.ntfy-sh;
    user = "ntfy";
    group = "ntfy";
    settings = {
      upstream-base-url = "https://ntfy.sh";
      base-url = "https://ntfy.sjanglab.org";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;

      # Admin user managed in auth-file DB (/var/lib/ntfy/user.db)
      # Provision: ntfy user add --role=admin <username>
      auth-default-access = "deny-all";
      auth-file = "/var/lib/ntfy/user.db";

      attachment-total-size-limit = "5G";
      attachment-file-size-limit = "15M";
      attachment-expiry-duration = "3h";
      attachment-cache-dir = "/var/lib/ntfy/attachments";

      cache-duration = "12h";
      cache-file = "/var/lib/ntfy/cache.db";

      log-level = "INFO";

      enable-signup = false;
      enable-login = true;
      enable-reservations = true;

      visitor-request-limit-burst = 200;
      visitor-request-limit-replenish = "5s";
      visitor-message-daily-limit = 15000;
    };
  };

  systemd.services.ntfy-sh.serviceConfig.DynamicUser = lib.mkForce false;

  users.users.ntfy = {
    isSystemUser = true;
    group = "ntfy";
  };
  users.groups.ntfy = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/ntfy 0755 ntfy ntfy"
    "d /var/cache/ntfy 0755 ntfy ntfy"
    "d /var/log/ntfy 0755 ntfy ntfy"
  ];

  security.acme.certs."ntfy.sjanglab.org" = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
  };

  services.nginx.virtualHosts."ntfy.sjanglab.org" = {
    forceSSL = true;
    enableACME = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:2586";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 3m;
        proxy_send_timeout 3m;
        proxy_read_timeout 3m;

        proxy_buffering off;
        proxy_request_buffering off;
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
