{ config, pkgs, ... }:
let
  inherit (config.networking.sbee) hosts;
  authentikAuth = import ../authentik/nginx-locations.nix { inherit hosts; };
  n8nDomain = "n8n.sjanglab.org";

  # External hook for Authentik forward auth integration
  # Reads X-authentik-email header and issues n8n session cookie
  hooksFile = pkgs.writeText "n8n-forward-auth-hooks.js" ''
    const { resolve } = require('path');
    const fs = require('fs');
    const n8nBasePath = '${pkgs.n8n}/lib/n8n';
    const pnpmDir = resolve(n8nBasePath, 'node_modules/.pnpm');
    const routerDir = fs.readdirSync(pnpmDir).find(dir => dir.startsWith('router@'));
    const Layer = require(resolve(pnpmDir, routerDir, 'node_modules/router/lib/layer'));
    const { issueCookie } = require(resolve(n8nBasePath, 'packages/cli/dist/auth/jwt'));

    const ignoreAuthRegexp = /^\/(assets|healthz|webhook|webhook-test|rest\/oauth2-credential)/;

    module.exports = {
      n8n: {
        ready: [
          async function ({ app }, config) {
            const { stack } = app.router;
            const index = stack.findIndex((l) => l.name === 'cookieParser');
            stack.splice(index + 1, 0, new Layer('/', {
              strict: false, end: false
            }, async (req, res, next) => {
              if (ignoreAuthRegexp.test(req.url)) return next();
              if (!config.get('userManagement.isInstanceOwnerSetUp', false)) return next();
              if (req.cookies?.['n8n-auth']) return next();
              if (!process.env.N8N_FORWARD_AUTH_HEADER) return next();

              const allowedHost = process.env.N8N_SSO_HOSTNAME;
              if (allowedHost && req.headers.host !== allowedHost) return next();

              const email = req.headers[process.env.N8N_FORWARD_AUTH_HEADER.toLowerCase()];
              if (!email) return next();

              const user = await this.dbCollections.User.findOneBy({ email });
              if (!user) {
                res.statusCode = 401;
                res.end("User '" + email + "' not found.");
                return;
              }
              if (!user.role) user.role = {};
              issueCookie(res, user);
              return next();
            }));
          },
        ],
      },
    };
  '';
in
{
  imports = [
    ../acme/sync.nix
    ../gatus/check.nix
  ];

  gatusCheck.push = [
    {
      name = "n8n";
      group = "apps";
      url = "http://127.0.0.1:5678/healthz";
    }
  ];

  acmeSyncer.mkReceiver = [
    {
      domain = n8nDomain;
      user = "acme-sync-n8n";
    }
  ];

  services.n8n = {
    enable = true;
    openFirewall = false;
    environment = {
      # Timezone (overrides system default)
      GENERIC_TIMEZONE = "Asia/Seoul";

      # Editor URL for webhooks
      N8N_EDITOR_BASE_URL = "https://${n8nDomain}";
      WEBHOOK_URL = "https://${n8nDomain}";

      # Disable telemetry
      N8N_DIAGNOSTICS_ENABLED = "false";
      N8N_VERSION_NOTIFICATIONS_ENABLED = "false";

      # Executions pruning
      EXECUTIONS_DATA_PRUNE = "true";
      EXECUTIONS_DATA_MAX_AGE = "336"; # 2 weeks in hours

      # Forward auth via Authentik
      EXTERNAL_HOOK_FILES = "${hooksFile}";
      N8N_FORWARD_AUTH_HEADER = "X-authentik-email";
      N8N_SSO_HOSTNAME = n8nDomain;

      # PostgreSQL (rho primary)
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = hosts.rho.wg-admin;
      DB_POSTGRESDB_PORT = "5432";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";

      # Password via _FILE suffix (read from systemd credentials)
      DB_POSTGRESDB_PASSWORD_FILE = "%d/db-password";
    };
  };

  sops.secrets.n8n-db-password = {
    sopsFile = ./secrets.yaml;
  };

  systemd.services.n8n.serviceConfig.LoadCredential = [
    "db-password:${config.sops.secrets.n8n-db-password.path}"
  ];

  # Firewall: wg-admin (for eta reverse proxy)
  networking.firewall.interfaces.wg-admin.allowedTCPPorts = [ 5678 ];

  # HTTPS via nginx for Tailscale access (split DNS)
  # Certificate synced from eta via rsync (same pattern as nextcloud)

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts.${n8nDomain} = {
      forceSSL = true;
      sslCertificate = "/var/lib/acme/${n8nDomain}/fullchain.pem";
      sslCertificateKey = "/var/lib/acme/${n8nDomain}/key.pem";

      locations = authentikAuth.locations // {
        # Webhook endpoints - no auth required
        "~ ^/(webhook|webhook-test)/" = {
          proxyPass = "http://127.0.0.1:5678";
          proxyWebsockets = true;
        };

        # Healthz endpoint - no auth required
        "= /healthz" = {
          proxyPass = "http://127.0.0.1:5678";
        };

        # Main location - protected by Authentik forward auth
        "/" = {
          proxyPass = "http://127.0.0.1:5678";
          proxyWebsockets = true;
          extraConfig = authentikAuth.protectLocation;
        };
      };
    };
  };

  # Firewall: HTTPS for Tailscale
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 443 ];
}
