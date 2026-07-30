{
  config,
  pkgs,
  ...
}:
let
  publicDomain = "mail.sjanglab.org";
  httpPort = 8082;
  adminPasswordFile = config.sops.secrets.stalwart-admin-password.path;
  r2Endpoint = "https://0572d3fa726276fa78f433d5ba90048e.r2.cloudflarestorage.com";
  primaryBlobBucket = "stalwart-mail-blobs";
in
{
  imports = [
    ./principals
    ./reverse-proxy.nix
    ./backup.nix
  ];

  services.stalwart = {
    enable = true;
    stateVersion = "25.05";

    settings = {
      config.local-keys = [
        "auth.*"
        "authentication.*"
        "certificate.*"
        "config.*"
        "directory.*"
        "http.*"
        "queue.route.local.*"
        "queue.route.resend.*"
        "queue.strategy.*"
        "resolver.*"
        "server.*"
        "!server.allowed-ip.*"
        "!server.blocked-ip.*"
        "session.*"
        "spam-filter.enable"
        "spam-filter.resource"
        "storage.*"
        "store.*"
        "tracer.*"
        "tracing.*"
        "webadmin.*"
      ];

      server = {
        hostname = publicDomain;
        tls = {
          enable = true;
          implicit = false;
        };
        listener = {
          smtp = {
            bind = [ "[::]:25" ];
            protocol = "smtp";
          };
          submissions = {
            bind = [ "[::]:465" ];
            protocol = "smtp";
            tls.implicit = true;
          };
          submission = {
            bind = [ "[::]:587" ];
            protocol = "smtp";
            tls.implicit = false;
          };
          imaptls = {
            bind = [ "[::]:993" ];
            protocol = "imap";
            tls.implicit = true;
          };
          http = {
            bind = [ "127.0.0.1:${toString httpPort}" ];
            protocol = "http";
            tls.implicit = false;
          };
          managesieve = {
            bind = [ "[::]:4190" ];
            protocol = "managesieve";
            tls.implicit = false;
          };
        };
      };

      certificate.default = {
        cert = "%{file:/var/lib/acme/${publicDomain}/fullchain.pem}%";
        private-key = "%{file:/var/lib/acme/${publicDomain}/key.pem}%";
        default = true;
      };

      storage = {
        data = "postgresql";
        fts = "postgresql";
        blob = "mail-blobs";
        lookup = "postgresql";
        directory = "internal";
      };
      store = {
        postgresql = {
          type = "postgresql";
          host = "/run/postgresql";
          port = 5432;
          database = "stalwart-mail";
          user = "stalwart-mail";
          # Unix-socket peer authentication ignores this required field.
          password = "unused";
          timeout = "15s";
          tls.enable = false;
          pool.max-connections = 3;
        };
        mail-blobs = {
          type = "s3";
          region = "auto";
          bucket = primaryBlobBucket;
          endpoint = r2Endpoint;
          access-key = "%{file:${config.sops.secrets.stalwart-r2-access-key-id.path}}%";
          secret-key = "%{file:${config.sops.secrets.stalwart-r2-secret-access-key.path}}%";
        };
      };
      directory.internal = {
        type = "internal";
        store = "postgresql";
      };

      authentication.fallback-admin = {
        user = "admin";
        secret = "%{file:${adminPasswordFile}}%";
      };

      http = {
        url = "'https://${publicDomain}'";
        use-x-forwarded = true;
      };

      resolver = {
        type = "system";
        public-suffix = [
          "file://${pkgs.publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
        ];
      };

      auth.dkim.sign = false;

      session.auth = {
        mechanisms = [
          {
            "if" = "local_port != 25";
            "then" = "[plain, login]";
          }
          { "else" = false; }
        ];
        directory = [
          {
            "if" = "local_port != 25";
            "then" = "'internal'";
          }
          { "else" = false; }
        ];
      };

      queue.strategy.route = [
        {
          "if" = "is_local_domain('', rcpt_domain)";
          "then" = "'local'";
        }
        { "else" = "'resend'"; }
      ];
      queue.route = {
        local.type = "local";
        resend = {
          type = "relay";
          address = "smtp.resend.com";
          port = 465;
          protocol = "smtp";
          tls = {
            implicit = true;
            allow-invalid-certs = false;
          };
          auth = {
            enable = true;
            username = "resend";
            secret = "%{file:${config.sops.secrets.resend-api-key.path}}%";
          };
        };
      };

      spam-filter = {
        enable = true;
        resource = "file://${pkgs.stalwart.passthru.spam-filter}/spam-filter.toml";
      };

      webadmin = {
        enable = true;
        path = "/var/cache/stalwart-mail";
        resource = "file://${pkgs.stalwart.passthru.webadmin}/webadmin.zip";
      };

      tracing.stdout = {
        enable = true;
        level = "info";
        ansi = false;
      };
      tracer.stdout = {
        type = "stdout";
        enable = true;
        level = "info";
        ansi = false;
      };
    };
  };

  sops.secrets = {
    resend-api-key = {
      sopsFile = ./secrets.yaml;
      owner = "stalwart-mail";
    };
    stalwart-admin-password = {
      sopsFile = ./secrets.yaml;
      owner = "stalwart-mail";
    };
    stalwart-r2-access-key-id = {
      sopsFile = ./secrets.yaml;
      owner = "stalwart-mail";
    };
    stalwart-r2-secret-access-key = {
      sopsFile = ./secrets.yaml;
      owner = "stalwart-mail";
    };
  };

  services.postgresql = {
    ensureDatabases = [ "stalwart-mail" ];
    ensureUsers = [
      {
        name = "stalwart-mail";
        ensureDBOwnership = true;
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [
    25
    465
    587
    993
    4190
  ];

  systemd.services.stalwart = {
    after = [
      "acme-finished-${publicDomain}.target"
      "postgresql.service"
    ];
    wants = [ "acme-finished-${publicDomain}.target" ];
    requires = [ "postgresql.service" ];
    environment.STALWART_PUBLIC_URL = "https://${publicDomain}";
  };
}
