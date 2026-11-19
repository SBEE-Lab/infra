# Linux Audit daemon configuration for SSH session tracking
# Generates session IDs for correlation across jumphost and internal hosts
{
  config,
  lib,
  pkgs,
  ...
}:
let
  nginxUid = toString config.ids.uids.nginx;
in
{
  # Enable audit subsystem
  security.audit = {
    enable = true;
    # The default 1024 overflowed and dropped events on eta, tau and psi.
    backlogLimit = 8192;

    # Audit rules - minimal set for SSH session tracking
    rules = [
      # Track user login/logout events (PAM sessions)
      "-w /var/log/wtmp -p wa -k session"
      "-w /var/log/btmp -p wa -k session"
      "-w /var/run/utmp -p wa -k session"

      # Track SSH authentication
      "-w /etc/ssh/sshd_config -p wa -k sshd_config"

      # nginx workers never exec; any exec means a compromised worker.
      "-a always,exit -F arch=b64 -S execve,execveat -F uid=${nginxUid} -k nginx_exec"
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 "-a always,exit -F arch=b32 -S execve,execveat -F uid=${nginxUid} -k nginx_exec";
  };

  # Enable auditd daemon
  security.auditd.enable = true;

  # auditd configuration (nixos-25.05 doesn't have settings option)
  environment.etc."audit/auditd.conf".text = ''
    # Minimal local storage - logs go to journald then Vector
    log_file = /var/log/audit/audit.log
    log_format = ENRICHED
    log_group = root
    priority_boost = 4
    flush = incremental_async
    freq = 50
    max_log_file = 8
    num_logs = 2
    max_log_file_action = rotate
    space_left = 50
    space_left_action = syslog
    admin_space_left = 20
    admin_space_left_action = syslog
    disk_full_action = syslog
    disk_error_action = syslog
  '';

  # Forward audit logs to journald for Vector to collect
  services.journald.settings.Journal.Audit = true;
}
