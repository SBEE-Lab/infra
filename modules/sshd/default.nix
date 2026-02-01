{
  lib,
  config,
  ...
}:
let
  cert = ./certs + "/${config.networking.hostName}-cert.pub";

  # eta is the only bastion host (SSH exposed to internet)
  isBastion = config.networking.hostName == "eta";

  otherPublicIPs = lib.mapAttrsToList (_name: host: host.ipv4) (
    lib.filterAttrs (_name: host: builtins.elem "public-ip" host.tags) config.networking.sbee.others
  );

  hasWhitelist = otherPublicIPs != [ ];

  ssh = {
    port = 10022;
    maxAuthTries = 3;
    loginGraceTime = 30;
    clientAliveInterval = 1200;
    clientAliveCountMax = 3;
  };

  fail2ban = {
    maxRetry = 3;
    findTime = 600;
    banTime = 86400;
    aggressiveBanTime = 604800;
  };

  rateLimiting = {
    timeWindow = 60;
    maxAttempts = 5;
  };
in
{
  # ========== SSH server ==========
  services.openssh = {
    enable = true;
    ports = [ ssh.port ];
    openFirewall = false; # We manage firewall rules manually based on bastion role

    settings = {
      X11Forwarding = false;
      PubkeyAuthentication = true;
      PermitEmptyPasswords = false;

      MaxAuthTries = ssh.maxAuthTries;
      LoginGraceTime = ssh.loginGraceTime;

      PermitUserEnvironment = false;
      Compression = false;

      TCPKeepAlive = true;
      ClientAliveInterval = ssh.clientAliveInterval;
      ClientAliveCountMax = ssh.clientAliveCountMax;

      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
      ];

      KexAlgorithms = [
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
        "diffie-hellman-group16-sha512"
        "diffie-hellman-group18-sha512"
      ];

      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
    };

    extraConfig = ''
      ${lib.optionalString (builtins.pathExists cert) ''
        HostCertificate ${cert}
      ''}
      StreamLocalBindUnlink yes

      PermitRootLogin no

      Match Address 10.100.0.0/24
          PermitRootLogin prohibit-password
    '';
  };

  # ========== SSH CA ==========
  warnings = lib.optional (
    !builtins.pathExists cert && config.networking.hostName != "nixos"
  ) "No ssh certificate found at ${toString cert}";

  programs.ssh.knownHosts.ssh-ca = {
    certAuthority = true;
    hostNames = lib.mapAttrsToList (n: _: n) config.networking.sbee.others;
    publicKeyFile = ./certs/ssh-ca.pub;
  };

  # ========== fail2ban (bastion only) ==========
  services.fail2ban = lib.mkIf isBastion {
    enable = true;
    maxretry = fail2ban.maxRetry;

    ignoreIP = [
      "127.0.0.1/8"
      "::1/128"
      "10.0.0.0/8"
    ]
    ++ otherPublicIPs;

    jails = {
      sshd = {
        settings = {
          enabled = true;
          inherit (ssh) port;
          filter = "sshd";
          maxretry = fail2ban.maxRetry;
          findtime = fail2ban.findTime;
          bantime = fail2ban.banTime;
          backend = "systemd";
        };
      };

      sshd-aggressive = {
        settings = {
          enabled = true;
          inherit (ssh) port;
          filter = "sshd[mode=aggressive]";
          maxretry = 1;
          findtime = fail2ban.banTime;
          bantime = fail2ban.aggressiveBanTime;
          backend = "systemd";
        };
      };
    };
  };

  # ========== firewall ==========
  # Bastion: SSH exposed to internet with rate limiting
  # Non-bastion: SSH only via WireGuard (wg-admin)
  networking.firewall = {
    enable = true;
  }
  // (
    if isBastion then
      {
        allowedTCPPorts = [ ssh.port ];

        extraCommands = ''
          ${lib.optionalString hasWhitelist ''
            ${lib.concatMapStringsSep "\n" (ip: ''
              iptables -I INPUT -s ${ip} -p tcp --dport ${toString ssh.port} -j ACCEPT
            '') otherPublicIPs}
          ''}

          iptables -A INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString ssh.port} \
            -m state --state NEW -m recent --set --name SSH
          iptables -A INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString ssh.port} \
            -m state --state NEW -m recent --update \
            --seconds ${toString rateLimiting.timeWindow} \
            --hitcount ${toString rateLimiting.maxAttempts} \
            --name SSH -j DROP
        '';

        extraStopCommands = ''
          ${lib.optionalString hasWhitelist ''
            ${lib.concatMapStringsSep "\n" (ip: ''
              iptables -D INPUT -s ${ip} -p tcp --dport ${toString ssh.port} -j ACCEPT 2>/dev/null || true
            '') otherPublicIPs}
          ''}

          iptables -D INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString ssh.port} \
            -m state --state NEW -m recent --set --name SSH 2>/dev/null || true
          iptables -D INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString ssh.port} \
            -m state --state NEW -m recent --update \
            --seconds ${toString rateLimiting.timeWindow} \
            --hitcount ${toString rateLimiting.maxAttempts} \
            --name SSH -j DROP 2>/dev/null || true
        '';
      }
    else
      {
        interfaces.wg-admin.allowedTCPPorts = [ ssh.port ];
      }
  );
}
