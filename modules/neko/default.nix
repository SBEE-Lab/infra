{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  ports = {
    ui = {
      host = 8082;
      container = 8080;
    };
    media = 59000;
    cdp = {
      host = 9222;
      chromium = 9222;
      relay = 9223;
    };
  };

  domain = "rho.n";
  publicDomain = "neko.sjanglab.org";
  publicURL = "https://${publicDomain}";
  backendPort = 18082;
  state = "/var/lib/neko";
  profile = "/var/lib/neko/chrome-profile";

  network = {
    name = "neko";
    interface = "neko0";
    id = "6e656b6f00000000000000000000000000000000000000000000000000000000";
    ipv4 = {
      subnet = "10.89.0.0/24";
      gateway = "10.89.0.1";
    };
    ipv6 = {
      subnet = "fd89:6e65:6b6f::/64";
      gateway = "fd89:6e65:6b6f::1";
    };
  };

  image = self.packages.${pkgs.stdenv.hostPlatform.system}.neko-image;

  podmanNetworkConfig = (pkgs.formats.json { }).generate "neko-podman-network.json" {
    inherit (network) name;
    inherit (network) id;
    driver = "bridge";
    network_interface = network.interface;
    created = "2026-08-10T00:00:00Z";
    subnets = [
      network.ipv4
      network.ipv6
    ];
    ipv6_enabled = true;
    internal = false;
    dns_enabled = false;
    ipam_options.driver = "host-local";
    options.isolate = "true";
  };

  clearStaleChromiumProcessLocks = pkgs.writeShellScript "neko-clear-stale-chromium-process-locks" ''
    # The previous container is gone, so persistent locks can only refer to dead runtime state.
    rm -f \
      ${profile}/SingletonCookie \
      ${profile}/SingletonLock \
      ${profile}/SingletonSocket
  '';

  chromiumConfig = pkgs.writeText "neko-chromium.conf" ''
    [program:chromium]
    environment=HOME="/home/%(ENV_USER)s",USER="%(ENV_USER)s",DISPLAY="%(ENV_DISPLAY)s"
    command=/usr/bin/chromium
      --no-sandbox
      --window-position=0,0
      --display=%(ENV_DISPLAY)s
      --user-data-dir=/home/neko/chrome-profile
      --remote-debugging-address=127.0.0.1
      --remote-debugging-port=${toString ports.cdp.chromium}
      --no-first-run
      --start-maximized
      --force-dark-mode
      --disable-file-system
      --disable-dev-shm-usage
    stopsignal=INT
    autorestart=true
    priority=800
    user=%(ENV_USER)s
    stdout_logfile=/var/log/neko/chromium.log
    stdout_logfile_maxbytes=100MB
    stdout_logfile_backups=10
    redirect_stderr=true

    [program:openbox]
    environment=HOME="/home/%(ENV_USER)s",USER="%(ENV_USER)s",DISPLAY="%(ENV_DISPLAY)s"
    command=/usr/bin/openbox --config-file /etc/neko/openbox.xml
    autorestart=true
    priority=300
    user=%(ENV_USER)s
    stdout_logfile=/var/log/neko/openbox.log
    stdout_logfile_maxbytes=100MB
    stdout_logfile_backups=10
    redirect_stderr=true

    # Chromium ignores remote-debugging-address in this image. Keep it on
    # loopback and expose full native CDP through a transport-only relay.
    [program:cdp-relay]
    command=/usr/local/bin/socat TCP-LISTEN:${toString ports.cdp.relay},fork,reuseaddr TCP:127.0.0.1:${toString ports.cdp.chromium}
    autorestart=true
    priority=900
    user=%(ENV_USER)s
    stdout_logfile=/var/log/neko/cdp-relay.log
    stdout_logfile_maxbytes=10MB
    stdout_logfile_backups=2
    redirect_stderr=true
  '';

  chromiumPolicy = pkgs.writeText "neko-chromium-policy.json" (
    builtins.toJSON {
      AutofillAddressEnabled = false;
      AutofillCreditCardEnabled = false;
      AutoplayAllowed = true;
      BrowserAddPersonEnabled = false;
      BrowserGuestModeEnabled = false;
      BrowserLabsEnabled = false;
      BrowserSignin = 0;
      CommandLineFlagSecurityWarningsEnabled = false;
      DefaultCookiesSetting = 1;
      DefaultNotificationsSetting = 2;
      DefaultPopupsSetting = 2;
      DeveloperToolsAvailability = 1;
      DownloadRestrictions = 3;
      EditBookmarksEnabled = false;
      ExtensionInstallBlocklist = [ "*" ];
      FullscreenAllowed = true;
      IncognitoModeAvailability = 1;
      PasswordManagerEnabled = false;
      PromptForDownloadLocation = false;
      RestoreOnStartup = 1;
      SyncDisabled = true;
      VideoCaptureAllowed = true;
    }
  );

in
{
  sops.secrets.neko-oidc-client-secret = {
    sopsFile = ../../terraform/authentik/neko-secrets.yaml;
    key = "NEKO_OAUTH_CLIENT_SECRET";
  };
  sops.templates.neko-oauth-env = {
    content = ''
      NEKO_MEMBER_OAUTH_CLIENT_SECRET=${config.sops.placeholder.neko-oidc-client-secret}
    '';
    restartUnits = [ "podman-neko.service" ];
  };

  # ca.x is cask's Dure CA endpoint. Dure's current ca.n default is not
  # published, so keep this private alias explicit until the registry owns it.
  networking.extraHosts = lib.mkAfter ''
    fdec:ca5f:90ad:6fdd:8e76:62fc:c0f7:297d ca.x
  '';

  # A private .n certificate keeps OAuth callbacks inside Naru.
  # acme-setup owns /var/lib/acme as acme:acme, including certificates
  # received by acme-sync. Keep nginx able to read both local and synced keys.
  users.groups.acme.members = [ "nginx" ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "sjang.bioe@gmail.com";
    certs.${domain}.server = "https://ca.x/acme/acme/directory";
  };
  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      enableACME = true;
      addSSL = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
        {
          addr = "[::]";
          port = 80;
        }
        {
          addr = "0.0.0.0";
          port = ports.ui.host;
          ssl = true;
        }
        {
          addr = "[::]";
          port = ports.ui.host;
          ssl = true;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString backendPort}";
        proxyWebsockets = true;
        extraConfig = ''
          if ($scheme = http) {
            return 301 ${publicURL}$request_uri;
          }
          proxy_set_header X-Real-IP $http_x_real_ip;
          proxy_set_header X-Forwarded-For $http_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-Host ${publicDomain};
          proxy_read_timeout 3600s;
        '';
      };
    };
  };

  networking.nftables.enable = true;

  # Browser credentials stay local; offsite backup sources exclude this path.
  systemd.tmpfiles.rules = [
    "d ${state} 0700 1000 1000 -"
    "d ${profile} 0700 1000 1000 -"
  ];

  environment.etc."containers/networks/${network.name}.json".source = podmanNetworkConfig;

  networking.firewall.interfaces."tinc.naru" = {
    allowedTCPPorts = [
      80 # Private ACME HTTP-01 challenge.
      ports.ui.host
      ports.media
    ];
    allowedUDPPorts = [ ports.media ];
  };

  networking.firewall.extraForwardRules = ''
    iifname "tinc.naru" oifname "${network.interface}" tcp dport ${toString ports.media} accept
    iifname "tinc.naru" oifname "${network.interface}" udp dport ${toString ports.media} accept
    iifname "${network.interface}" oifname "tinc.naru" ct state established,related accept
  '';

  # Keep the browser away from rho and overlay-network services if a visited
  # page compromises Chromium. Internet egress remains available.
  networking.nftables.tables.neko-isolation = {
    family = "inet";
    content = ''
      chain input {
        type filter hook input priority -5; policy accept;
        # Wildcard listeners avoid coupling nginx startup to Naru address readiness.
        # Restrict even trusted WireGuard interfaces to preserve Naru-only access.
        tcp dport ${toString ports.ui.host} iifname != { "lo", "tinc.naru" } drop
        tcp dport ${toString ports.ui.host} iifname "tinc.naru" meta nfproto ipv4 ip saddr != 10.208.0.2 drop
        tcp dport ${toString ports.ui.host} iifname "tinc.naru" meta nfproto ipv6 ip6 saddr != fdec:ca5f:65b0:70ce:6397:a143:8f96:9818 drop
        iifname "${network.interface}" icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert } accept
        iifname "${network.interface}" ct state established,related accept
        iifname "${network.interface}" drop
      }

      chain forward {
        type filter hook forward priority -5; policy accept;
        ct state established,related accept
        # Container DNAT bypasses the host input firewall; restrict ingress here too.
        oifname "${network.interface}" iifname != "tinc.naru" drop
        iifname "${network.interface}" ip daddr {
          10.0.0.0/8,
          100.64.0.0/10,
          127.0.0.0/8,
          169.254.0.0/16,
          172.16.0.0/12,
          192.168.0.0/16
        } drop
        iifname "${network.interface}" ip6 daddr { ::1/128, fc00::/7, fe80::/10 } drop
      }
    '';
  };

  systemd.services.podman-neko = {
    after = [ "systemd-tmpfiles-setup.service" ];
    # OCI pre-start removes the old container before persistent process locks are cleared.
    serviceConfig.ExecStartPre = lib.mkAfter [ clearStaleChromiumProcessLocks ];
    restartTriggers = [
      podmanNetworkConfig
      chromiumConfig
      chromiumPolicy
      image
      pkgs.pkgsStatic.socat
    ];
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers.neko = {
      image = "${image.imageName}:${image.imageTag}";
      imageFile = image;
      pull = "never";
      hostname = "neko";
      networks = [ network.name ];
      environmentFiles = [ config.sops.templates.neko-oauth-env.path ];
      environment = {
        NEKO_DESKTOP_SCREEN = "1920x1080@30";
        NEKO_MEMBER_PROVIDER = "oauth";
        NEKO_MEMBER_OAUTH_ENABLED = "true";
        NEKO_MEMBER_OAUTH_AUTO_REDIRECT = "true";
        NEKO_MEMBER_OAUTH_NAME = "Authentik";
        NEKO_MEMBER_OAUTH_CLIENT_ID = "neko-rho";
        NEKO_MEMBER_OAUTH_ISSUER_URL = "https://auth.sjanglab.org/application/o/neko/";
        NEKO_MEMBER_OAUTH_REDIRECT_URL = "${publicURL}/api/oauth/callback";
        NEKO_MEMBER_OAUTH_SCOPES = "openid profile email neko-role";
        NEKO_MEMBER_OAUTH_SUBJECT_FIELD = "sub";
        NEKO_MEMBER_OAUTH_USERNAME_FIELD = "preferred_username";
        NEKO_SERVER_CORS = publicURL;
        NEKO_SERVER_PROXY = "true";
        NEKO_SESSION_COOKIE_ENABLED = "true";
        NEKO_SESSION_COOKIE_SECURE = "true";
        NEKO_WEBRTC_ICELITE = "true";
        # Keep direct Naru access while eta forwards the public IPv4 candidate.
        NEKO_WEBRTC_NAT1TO1 = "${config.networking.sbee.hosts.eta.ipv4} ${config.networking.naru.ipv6}";
        NEKO_WEBRTC_TCPMUX = toString ports.media;
        NEKO_WEBRTC_UDPMUX = toString ports.media;
        TZ = "Asia/Seoul";
      };
      ports = [
        "127.0.0.1:${toString backendPort}:${toString ports.ui.container}/tcp"
        "${config.networking.naru.ipv4}:${toString ports.media}:${toString ports.media}/tcp"
        "${config.networking.naru.ipv4}:${toString ports.media}:${toString ports.media}/udp"
        "[${config.networking.naru.ipv6}]:${toString ports.media}:${toString ports.media}/tcp"
        "[${config.networking.naru.ipv6}]:${toString ports.media}:${toString ports.media}/udp"
        "127.0.0.1:${toString ports.cdp.host}:${toString ports.cdp.relay}/tcp"
      ];
      volumes = [
        "${profile}:/home/neko/chrome-profile:rw"
        "${chromiumConfig}:/etc/neko/supervisord/chromium.conf:ro"
        "${chromiumPolicy}:/etc/chromium/policies/managed/policies.json:ro"
        "${pkgs.pkgsStatic.socat}/bin/socat:/usr/local/bin/socat:ro"
      ];
      extraOptions = [
        "--device=/dev/dri/renderD128:/dev/dri/renderD128"
        "--dns=1.1.1.1"
        "--dns=8.8.8.8"
        "--pids-limit=512"
        "--security-opt=no-new-privileges"
        "--shm-size=2g"
      ];
    };
  };

}
