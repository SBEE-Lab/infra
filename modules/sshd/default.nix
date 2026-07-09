{
  lib,
  config,
  pkgs,
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
    # Exponential backoff: ban doubles per re-offense from base to cap.
    baseBanTime = 300;
    maxBanTime = 604800;
  };

  rateLimiting = {
    timeWindow = 60;
    maxAttempts = 5;
  };

  bastionTargets = lib.mapAttrs (_name: host: host.wg-admin) (
    lib.filterAttrs (_name: host: host ? wg-admin && host.wg-admin != null) config.networking.sbee.hosts
  );

  bastionTargetsFile = pkgs.writeText "ssh-bastion-targets.json" (builtins.toJSON bastionTargets);
  lokiUrl = "http://${config.networking.sbee.hosts.rho.wg-admin}:3100";

  pamBastionSessionScript = pkgs.writeShellScript "ssh-bastion-pam-session" ''
    exec ${pkgs.python3}/bin/python3 - <<'PY'
    import json
    import os
    import time

    def parent(pid: int) -> int:
        try:
            with open(f"/proc/{pid}/status", "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("PPid:"):
                        return int(line.split()[1])
        except OSError:
            return 0
        return 0

    def comm(pid: int) -> str:
        try:
            with open(f"/proc/{pid}/comm", "r", encoding="utf-8") as f:
                return f.read().strip()
        except OSError:
            return ""

    pid = os.getppid()
    sshd_pid = 0
    while pid > 1:
        if comm(pid) == "sshd-session":
            sshd_pid = pid
            break
        pid = parent(pid)

    if sshd_pid == 0:
        raise SystemExit(0)

    session_dir = "/run/ssh-bastion-audit/sessions"
    os.makedirs(session_dir, mode=0o700, exist_ok=True)
    event = {
        "seen_at": time.time(),
        "bastion_pid": str(sshd_pid),
        "bastion_user": os.environ.get("PAM_USER", ""),
        "source_ip": os.environ.get("PAM_RHOST", ""),
        "source_port": "",
        "auth_method": "pam_session",
        "key_type": "",
        "key_fingerprint": "",
    }
    path = os.path.join(session_dir, f"{sshd_pid}.json")
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(event, f, sort_keys=True)
    os.replace(tmp, path)
    PY
  '';

  bastionAuditScript = pkgs.writeShellScript "ssh-bastion-audit" ''
    exec ${pkgs.python3}/bin/python3 ${pkgs.writeText "ssh-bastion-audit.py" ''
      import json
      import os
      import re
      import socket
      import sys
      import time
      import urllib.request

      with open(sys.argv[1], "r", encoding="utf-8") as f:
          target_map = json.load(f)
      loki_url = sys.argv[2].rstrip("/")

      target_by_ip = {ip: host for host, ip in target_map.items()}
      session_dir = "/run/ssh-bastion-audit/sessions"
      auth_by_pid = {}
      emitted = {}
      max_age = 24 * 60 * 60

      def cleanup(now: float) -> None:
          for pid in [pid for pid, info in auth_by_pid.items() if now - info["seen_at"] > max_age]:
              del auth_by_pid[pid]
          for key in [key for key, seen_at in emitted.items() if now - seen_at > max_age]:
              del emitted[key]

      def emit(event: dict[str, object]) -> None:
          line = json.dumps(event, sort_keys=True)
          print(line, flush=True)

          labels = {
              "host": "eta",
              "log_type": "ssh_bastion",
              "event": "bastion_forward",
              "target_host": str(event.get("target_host", "unknown")),
              "bastion_user": str(event.get("bastion_user", "unknown")),
          }
          payload = {
              "streams": [
                  {
                      "stream": labels,
                      "values": [[str(time.time_ns()), line]],
                  }
              ]
          }
          request = urllib.request.Request(
              f"{loki_url}/loki/api/v1/push",
              data=json.dumps(payload).encode("utf-8"),
              headers={"Content-Type": "application/json"},
              method="POST",
          )
          try:
              urllib.request.urlopen(request, timeout=5).read()
          except Exception as error:
              print(f"failed to push ssh bastion audit event to Loki: {error}", file=sys.stderr, flush=True)

      def decode_ipv4(hex_addr: str) -> str:
          return socket.inet_ntoa(bytes.fromhex(hex_addr)[::-1])

      def tcp_table() -> dict[str, dict[str, object]]:
          sockets = {}
          try:
              with open("/proc/net/tcp", "r", encoding="utf-8") as f:
                  lines = f.readlines()[1:]
          except OSError:
              return sockets

          for line in lines:
              fields = line.split()
              if len(fields) < 10:
                  continue
              local_addr, local_port_hex = fields[1].split(":")
              remote_addr, remote_port_hex = fields[2].split(":")
              sockets[fields[9]] = {
                  "local_ip": decode_ipv4(local_addr),
                  "local_port": str(int(local_port_hex, 16)),
                  "remote_ip": decode_ipv4(remote_addr),
                  "remote_port": str(int(remote_port_hex, 16)),
                  "state": fields[3],
              }
          return sockets

      def process_fields(pid: str) -> dict[str, str]:
          try:
              with open(f"/proc/{pid}/status", "r", encoding="utf-8") as f:
                  return dict(line.split(":", 1) for line in f if line.startswith(("Name:", "PPid:")))
          except OSError:
              return {}

      def process_args(pid: str) -> str:
          try:
              with open(f"/proc/{pid}/cmdline", "rb") as f:
                  return f.read().replace(b"\0", b" ").decode("utf-8", "replace").strip()
          except OSError:
              return ""

      def sshd_session_pids() -> list[str]:
          pids = []
          for name in os.listdir("/proc"):
              if name.isdigit() and process_fields(name).get("Name", "").strip() == "sshd-session":
                  pids.append(name)
          return pids

      def parent_pid(pid: str) -> str:
          return process_fields(pid).get("PPid", "").strip()

      def child_pids(root_pid: str) -> list[str]:
          return [pid for pid in sshd_session_pids() if parent_pid(pid) == root_pid]

      def parse_user_from_args(args: str) -> str:
          match = re.search(r"sshd-session: ([^ @\[]+)", args)
          if match:
              return match.group(1)
          return ""

      def infer_auth(pid: str, table: dict[str, dict[str, object]]) -> dict[str, object]:
          candidates = [pid]
          parent = parent_pid(pid)
          if parent:
              candidates.append(parent)
          candidates.extend(child_pids(pid))

          user = ""
          source_ip = ""
          source_port = ""
          for candidate in candidates:
              if not user:
                  user = parse_user_from_args(process_args(candidate))
              for inode in pid_socket_inodes(candidate):
                  conn = table.get(inode)
                  if conn is None:
                      continue
                  if str(conn["local_port"]) == "10022":
                      source_ip = str(conn["remote_ip"])
                      source_port = str(conn["remote_port"])
                      break
              if source_ip:
                  break

          return {
              "seen_at": time.time(),
              "bastion_pid": pid,
              "bastion_user": user,
              "source_ip": source_ip,
              "source_port": source_port,
              "auth_method": "proc_socket",
              "key_type": "",
              "key_fingerprint": "",
          }

      def load_sessions(now: float) -> None:
          try:
              names = os.listdir(session_dir)
          except OSError:
              return
          for name in names:
              if not name.endswith(".json"):
                  continue
              path = os.path.join(session_dir, name)
              try:
                  with open(path, "r", encoding="utf-8") as f:
                      session = json.load(f)
              except (OSError, json.JSONDecodeError):
                  continue
              pid = str(session.get("bastion_pid", ""))
              seen_at = float(session.get("seen_at", 0))
              if not pid or now - seen_at > max_age:
                  try:
                      os.unlink(path)
                  except OSError:
                      pass
                  continue
              auth_by_pid[pid] = session

      def pid_socket_inodes(pid: str) -> set[str]:
          inodes = set()
          fd_dir = f"/proc/{pid}/fd"
          try:
              fds = os.listdir(fd_dir)
          except OSError:
              return inodes
          for fd in fds:
              try:
                  target = os.readlink(os.path.join(fd_dir, fd))
              except OSError:
                  continue
              if target.startswith("socket:[") and target.endswith("]"):
                  inodes.add(target[len("socket:[") : -1])
          return inodes

      while True:
          now = time.time()
          load_sessions(now)
          cleanup(now)
          table = tcp_table()
          auth_snapshot = dict(auth_by_pid)
          candidate_roots = set(auth_snapshot) | set(sshd_session_pids())

          for bastion_pid in candidate_roots:
              auth = auth_snapshot.get(bastion_pid) or infer_auth(bastion_pid, table)
              candidate_pids = [bastion_pid] + child_pids(bastion_pid)
              for pid in candidate_pids:
                  for inode in pid_socket_inodes(pid):
                      conn = table.get(inode)
                      if conn is None:
                          continue
                      target_ip = str(conn["remote_ip"])
                      target_port = str(conn["remote_port"])
                      target_host = target_by_ip.get(target_ip)

                      # Only record active SSH jumps into managed wg-admin hosts.
                      if target_port != "10022" or target_host is None:
                          continue

                      key = (pid, str(conn["local_port"]), target_ip, target_port)
                      if key in emitted:
                          continue
                      emitted[key] = now

                      event = {
                          "event": "bastion_forward",
                          "log_type": "ssh_bastion",
                          "host": "eta",
                          "bastion_pid": bastion_pid,
                          "bastion_child_pid": "" if pid == bastion_pid else pid,
                          "target_host": target_host,
                          "target_ip": target_ip,
                          "target_port": target_port,
                          "bastion_local_ip": conn["local_ip"],
                          "bastion_local_port": conn["local_port"],
                      }
                      event.update({k: v for k, v in auth.items() if k != "seen_at"})
                      event["message"] = (
                          f"SSH bastion forward: {event.get('source_ip', 'unknown')} -> "
                          f"{target_host} ({target_ip}:{target_port}) as {event.get('bastion_user', 'unknown')} "
                          f"via eta:{conn['local_port']}"
                      )
                      emit(event)
          time.sleep(1)
    ''} ${bastionTargetsFile} ${lokiUrl}
  '';
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

      # VERBOSE records public-key fingerprints but can make fail2ban count
      # every rejected offered key, so keep eta on INFO even though fail2ban
      # would otherwise raise sshd logging to VERBOSE.
      LogLevel = if isBastion then lib.mkForce "INFO" else "VERBOSE";

      MaxAuthTries = ssh.maxAuthTries;
      LoginGraceTime = ssh.loginGraceTime;

      PermitUserEnvironment = false;
      AcceptEnv = [ "NIKS3_SERVER_URL" ];
      Compression = false;

      TCPKeepAlive = true;
      ClientAliveInterval = ssh.clientAliveInterval;
      ClientAliveCountMax = ssh.clientAliveCountMax;

      # nix-fast-build opens many parallel sessions for build/download
      MaxSessions = 64;

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

  security.pam.services.sshd.rules.session.ssh-bastion-audit = lib.mkIf isBastion {
    order = config.security.pam.services.sshd.rules.session.unix.order + 10;
    control = "optional";
    modulePath = "pam_exec.so";
    args = [
      "seteuid"
      (toString pamBastionSessionScript)
    ];
  };

  systemd.tmpfiles.rules = lib.mkIf isBastion [
    "d /run/ssh-bastion-audit 0700 root root - -"
    "d /run/ssh-bastion-audit/sessions 0700 root root - -"
  ];

  systemd.services.ssh-bastion-audit = lib.mkIf isBastion {
    description = "Emit correlated SSH bastion forwarding audit events";
    wantedBy = [ "multi-user.target" ];
    after = [
      "sshd.service"
      "systemd-journald.service"
    ];
    serviceConfig = {
      ExecStart = bastionAuditScript;
      Restart = "always";
      RestartSec = "5s";
      User = "root";
      DynamicUser = false;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
      ];
      SystemCallFilter = [ "@system-service" ];
      MemoryMax = "256M";
    };
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

    # overalljails counts offenses per-IP across jails, not per-filter.
    bantime-increment = {
      enable = true;
      maxtime = toString fail2ban.maxBanTime;
      rndtime = "60"; # jitter to avoid synchronized ban expiry
      overalljails = true;
    };

    # Only ignoreIP truly whitelists: it is checked before banning, whereas the
    # iptables ACCEPT sits below the f2b jump chain and cannot override a ban.
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
          bantime = fail2ban.baseBanTime;
          backend = "systemd";
        };
      };

      # maxretry 3 (not 1): one preauth disconnect from a legit client must not
      # mean an instant ban. Backoff handles repeat abusers.
      sshd-aggressive = {
        settings = {
          enabled = true;
          inherit (ssh) port;
          filter = "sshd[mode=aggressive]";
          maxretry = fail2ban.maxRetry;
          findtime = fail2ban.findTime;
          bantime = fail2ban.baseBanTime;
          backend = "systemd";
        };
      };
    };
  };

  # Spare clients that reach the auth phase then drop (e.g. an unconfirmed
  # Secretive/Touch-ID prompt) from the aggressive jail. Anonymous floods lack
  # the "authenticating user" qualifier, so they are still caught.
  environment.etc."fail2ban/filter.d/sshd.local" = lib.mkIf isBastion {
    text = ''
      [Definition]
      ignoreregex = ^(?:Connection closed|Disconnected) by authenticating user \S+ <HOST> port \d+(?: \[preauth\])?\s*$
    '';
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

        # Emergency LAN access when bastion (eta) is down — whitelisted IPs only
        extraCommands = ''
          iptables -A INPUT -p tcp --dport ${toString ssh.port} \
            -m iprange --src-range 10.80.169.38-10.80.169.40 -j ACCEPT
        '';
        extraStopCommands = ''
          iptables -D INPUT -p tcp --dport ${toString ssh.port} \
            -m iprange --src-range 10.80.169.38-10.80.169.40 -j ACCEPT 2>/dev/null || true
        '';
      }
  );
}
