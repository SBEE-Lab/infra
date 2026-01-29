{
  lib,
  config,
  ...
}:
let
  cfg = config.networking.sbee.currentHost;
  cert = ./certs + "/${config.networking.hostName}-cert.pub";

  # ========== Nodes ==========
  isPublicNode = builtins.elem "public-ip" cfg.tags;

  otherPublicIPs = lib.mapAttrsToList (_name: host: host.ipv4) (
    lib.filterAttrs (_name: host: builtins.elem "public-ip" host.tags) config.networking.sbee.others
  );

  hasWhitelist = otherPublicIPs != [ ];

  # ========== Constants ==========
  security = {
    ssh = {
      port = 10022;
      maxAuthTries = 3;
      maxAuthTriesExternal = 2;
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
  };
in
{
  # ========== SSH services ==========
  services.openssh = {
    enable = true;
    ports = [ security.ssh.port ];

    settings = {
      X11Forwarding = false;
      PubkeyAuthentication = true;
      PermitEmptyPasswords = false;

      MaxAuthTries = security.ssh.maxAuthTries;
      LoginGraceTime = security.ssh.loginGraceTime;

      PermitUserEnvironment = false;
      Compression = false;

      TCPKeepAlive = true;
      ClientAliveInterval = security.ssh.clientAliveInterval;
      ClientAliveCountMax = security.ssh.clientAliveCountMax;

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

  # ========== SSH CA  ==========
  warnings = lib.optional (
    !builtins.pathExists cert && config.networking.hostName != "nixos"
  ) "No ssh certificate found at ${toString cert}";

  programs.ssh.knownHosts.ssh-ca = {
    certAuthority = true;
    hostNames = lib.mapAttrsToList (n: _: n) config.networking.sbee.others;
    publicKeyFile = ./certs/ssh-ca.pub;
  };

  # ========== fail2ban (for only public IP nodes) ==========
  services.fail2ban = lib.mkIf isPublicNode {
    enable = true;
    maxretry = security.fail2ban.maxRetry;

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
          inherit (security.ssh) port;
          filter = "sshd";
          maxretry = security.fail2ban.maxRetry;
          findtime = security.fail2ban.findTime;
          bantime = security.fail2ban.banTime;
          backend = "systemd";
        };
      };

      sshd-aggressive = {
        settings = {
          enabled = true;
          inherit (security.ssh) port;
          filter = "sshd[mode=aggressive]";
          maxretry = 1;
          findtime = security.fail2ban.banTime;
          bantime = security.fail2ban.aggressiveBanTime;
          backend = "systemd";
        };
      };
    };
  };

  # ========== firewall with rate limiting ==========
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ security.ssh.port ];

    extraCommands = lib.optionalString isPublicNode ''
      ${lib.optionalString hasWhitelist ''
        ${lib.concatMapStringsSep "\n" (ip: ''
          iptables -I INPUT -s ${ip} -p tcp --dport ${toString security.ssh.port} -j ACCEPT
        '') otherPublicIPs}
      ''}

      iptables -A INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString security.ssh.port} \
        -m state --state NEW -m recent --set --name SSH
      iptables -A INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString security.ssh.port} \
        -m state --state NEW -m recent --update \
        --seconds ${toString security.rateLimiting.timeWindow} \
        --hitcount ${toString security.rateLimiting.maxAttempts} \
        --name SSH -j DROP
    '';

    extraStopCommands = lib.optionalString isPublicNode ''
      ${lib.optionalString hasWhitelist ''
        ${lib.concatMapStringsSep "\n" (ip: ''
          iptables -D INPUT -s ${ip} -p tcp --dport ${toString security.ssh.port} -j ACCEPT 2>/dev/null || true
        '') otherPublicIPs}
      ''}

      iptables -D INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString security.ssh.port} \
        -m state --state NEW -m recent --set --name SSH 2>/dev/null || true
      iptables -D INPUT ! -s 10.0.0.0/8 -p tcp --dport ${toString security.ssh.port} \
        -m state --state NEW -m recent --update \
        --seconds ${toString security.rateLimiting.timeWindow} \
        --hitcount ${toString security.rateLimiting.maxAttempts} \
        --name SSH -j DROP 2>/dev/null || true
    '';
  };
}
