{ config, ... }:
let
  domain = config.services.nextcloud.hostName;
  port = 9980;
in
{
  imports = [
    ./fonts.nix
    ./spreadsheet-template.nix
  ];

  services.collabora-online = {
    enable = true;
    inherit port;
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

  services.nginx.virtualHosts.${domain}.locations = {
    # Static files
    "^~ /browser" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
    # WOPI discovery and capabilities
    "^~ /hosting/discovery" = {
      proxyPass = "http://127.0.0.1:${toString port}";
    };
    "^~ /hosting/capabilities" = {
      proxyPass = "http://127.0.0.1:${toString port}";
    };
    # All Collabora /cool/ paths including WebSocket (/cool/*/ws)
    # Must use ^~ to prevent Nextcloud's static file regex from intercepting
    "^~ /cool/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
  };
}
