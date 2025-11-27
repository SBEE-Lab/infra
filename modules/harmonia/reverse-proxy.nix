{config, ...}: let
  cacheDomain = "cache.sjanglab.org";
in {
  imports = [../acme];

  services.harmonia = {
    enable = true;
    signKeyPaths = [config.sops.secrets.harmonia-private-key.path];
    settings = {
      bind = "127.0.0.1:5000";
      workers = 4;
      max_connection_rate = 256;
      priority = 30;
    };
  };

  sops.secrets.harmonia-private-key = {
    sopsFile = ./secrets.yaml;
    owner = "harmonia";
    group = "harmonia";
    mode = "0400";
  };

  # Rate limiting configuration
  services.nginx = {
    appendHttpConfig = ''
      # Rate limiting zones for binary cache
      # General request rate: 30 req/s with burst of 100
      limit_req_zone $binary_remote_addr zone=cache_general:10m rate=30r/s;

      # NAR file downloads: more permissive (large files, less frequent)
      limit_req_zone $binary_remote_addr zone=cache_nar:10m rate=10r/s;

      # .narinfo requests: moderate rate (frequent but small)
      limit_req_zone $binary_remote_addr zone=cache_narinfo:10m rate=50r/s;

      # Connection limiting
      limit_conn_zone $binary_remote_addr zone=cache_conn:10m;

      # Geo-based access control map (optional, for future use)
      # Currently allows all, can be restricted to specific countries
      geo $cache_allowed {
        default 1;
        # Block specific ranges if needed:
        # 10.0.0.0/8 0;  # example
      }
    '';

    virtualHosts.${cacheDomain} = {
      forceSSL = true;
      enableACME = true;

      # Connection limits
      extraConfig = ''
        # Max 50 concurrent connections per IP
        limit_conn cache_conn 50;
        limit_conn_status 429;

        # Custom error pages for rate limiting
        error_page 429 = @rate_limited;
        error_page 503 = @service_unavailable;
      '';

      locations = {
        # Root and general endpoints
        "/" = {
          proxyPass = "http://127.0.0.1:5000";
          extraConfig = ''
            # General rate limiting
            limit_req zone=cache_general burst=100 nodelay;
            limit_req_status 429;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Cache control headers for clients
            add_header X-Cache-Status $upstream_cache_status;

            # Security headers
            add_header X-Content-Type-Options nosniff always;
            add_header X-Frame-Options DENY always;
          '';
        };

        # NAR files (large binary blobs) - more permissive rate, larger timeouts
        "~ ^/nar/" = {
          proxyPass = "http://127.0.0.1:5000";
          extraConfig = ''
            limit_req zone=cache_nar burst=20 nodelay;
            limit_req_status 429;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Longer timeouts for large file transfers
            proxy_connect_timeout 60s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;

            # Disable buffering for large files
            proxy_buffering off;
            proxy_request_buffering off;

            # Allow large responses
            proxy_max_temp_file_size 0;
          '';
        };

        # .narinfo files (metadata) - higher rate allowed
        "~ \\.narinfo$" = {
          proxyPass = "http://127.0.0.1:5000";
          extraConfig = ''
            limit_req zone=cache_narinfo burst=200 nodelay;
            limit_req_status 429;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # narinfo files are small, enable caching
            proxy_connect_timeout 10s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
          '';
        };

        # nix-cache-info endpoint
        "/nix-cache-info" = {
          proxyPass = "http://127.0.0.1:5000";
          extraConfig = ''
            limit_req zone=cache_narinfo burst=50 nodelay;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # This is a small static response, cache it
            proxy_cache_valid 200 1m;
          '';
        };

        # Rate limit error handler
        "@rate_limited" = {
          return = "429 'Rate limit exceeded. Please slow down your requests.\n'";
          extraConfig = ''
            default_type text/plain;
            add_header Retry-After 60 always;
          '';
        };

        # Service unavailable handler
        "@service_unavailable" = {
          return = "503 'Binary cache temporarily unavailable. Please try again later.\n'";
          extraConfig = ''
            default_type text/plain;
            add_header Retry-After 300 always;
          '';
        };

        # Health check endpoint (no rate limiting)
        "/health" = {
          return = "200 'OK\n'";
          extraConfig = ''
            default_type text/plain;
            access_log off;
          '';
        };
      };
    };
  };

  # ACME certificate for cache domain
  security.acme.certs.${cacheDomain} = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.secrets.cloudflare-credentials.path;
    webroot = null;
  };

  # Internal wireguard access (for faster internal network access)
  networking.firewall.interfaces.wg-serv.allowedTCPPorts = [5000];
}
