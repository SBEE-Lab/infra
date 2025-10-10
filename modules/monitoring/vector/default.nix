# Vector agent configuration for log/metrics collection
# - Collects sshd logs with user/IP extraction
# - Collects auditd session events for correlation
# - Streams to central Loki/Prometheus on rho
{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.networking) hostName;

  systemCollector = config.networking.sbee.hosts.rho.wg-mgnt;
  isSystemCollector = hostName == "rho";

  netStatsScript = pkgs.writeShellScript "net-stats.sh" ''
    #!/usr/bin/env bash
    for iface in /sys/class/net/*; do
      name=$(basename "$iface")
      [[ "$name" =~ ^(lo|veth|docker|br-) ]] && continue

      echo "{\"interface\":\"$name\",\"rx_bytes\":$(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0),\"tx_bytes\":$(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0),\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    done
  '';
in {
  imports = [
    ../auditd.nix
  ];

  services.vector = {
    enable = true;

    settings = {
      sources = {
        sshd_logs = {
          type = "journald";
          include_units = ["sshd"];
        };

        # Audit logs for session tracking
        audit_logs = {
          type = "journald";
          include_units = ["auditd"];
        };

        host_metrics = {
          type = "host_metrics";
          scrape_interval_secs = 60;
          collectors = ["cpu" "disk" "filesystem" "memory" "network"];
        };

        network_stats = {
          type = "exec";
          command = ["${netStatsScript}"];
          mode = "scheduled";
          scheduled.exec_interval_secs = 60;
          decoding.codec = "json";
        };
      };

      transforms = {
        # Parse SSH logs - extract user, IP, port, auth method
        parse_ssh = {
          type = "remap";
          inputs = ["sshd_logs"];
          source = ''
            .host = "${hostName}"
            .log_type = "ssh"

            message = string!(.message)
            .event = "other"

            # Accepted publickey for alice from 203.0.113.50 port 52431 ssh2
            # Failed password for bob from 192.168.1.100 port 22 ssh2
            if match(message, r'(Accepted|Failed)') {
              parsed = parse_regex(message, r'(?P<status>Accepted|Failed) (?P<method>\w+) for (?P<user>\S+) from (?P<ip>[\d.]+) port (?P<port>\d+)') ?? {}

              if exists(parsed.status) {
                .user = parsed.user
                .source_ip = parsed.ip
                .source_port = parsed.port
                .auth_method = parsed.method

                if parsed.status == "Accepted" {
                  .event = "login_success"
                } else {
                  .event = "login_failed"
                }
              }
            }

            # session closed for user alice
            if match(message, r'session closed') {
              .event = "session_closed"
              parsed = parse_regex(message, r'session closed for user (?P<user>\S+)') ?? {}
              if exists(parsed.user) {
                .user = parsed.user
              }
            }

            # session opened for user alice
            if match(message, r'session opened') {
              .event = "session_opened"
              parsed = parse_regex(message, r'session opened for user (?P<user>\S+)') ?? {}
              if exists(parsed.user) {
                .user = parsed.user
              }
            }

            # Disconnected/Connection closed
            if match(message, r'Disconnected|Connection closed') {
              .event = "disconnected"
              parsed = parse_regex(message, r'user (?P<user>\S+)') ?? {}
              if exists(parsed.user) {
                .user = parsed.user
              }
            }
          '';
        };

        # Parse audit logs - extract session ID for correlation
        parse_audit = {
          type = "remap";
          inputs = ["audit_logs"];
          source = ''
            .host = "${hostName}"
            .log_type = "audit"
            .event = "other"

            message = string!(.message)

            # USER_LOGIN: user login event with session ID
            # type=USER_LOGIN ... pid=1234 uid=0 auid=1000 ses=12345 ... acct="alice" addr=203.0.113.50
            if match(message, r'type=USER_LOGIN') {
              .event = "session_start"
              parsed = parse_regex(message, r'ses=(?P<ses>\d+)') ?? {}
              if exists(parsed.ses) { .session_id = parsed.ses }

              parsed_user = parse_regex(message, r'acct="(?P<user>[^"]+)"') ?? {}
              if exists(parsed_user.user) { .user = parsed_user.user }

              parsed_addr = parse_regex(message, r'addr=(?P<ip>[\d.]+)') ?? {}
              if exists(parsed_addr.ip) { .source_ip = parsed_addr.ip }
            }

            # USER_END: session end
            if match(message, r'type=USER_END') {
              .event = "session_end"
              parsed = parse_regex(message, r'ses=(?P<ses>\d+)') ?? {}
              if exists(parsed.ses) { .session_id = parsed.ses }

              parsed_user = parse_regex(message, r'acct="(?P<user>[^"]+)"') ?? {}
              if exists(parsed_user.user) { .user = parsed_user.user }
            }

            # USER_AUTH: authentication attempt
            if match(message, r'type=USER_AUTH') {
              .event = "auth_attempt"
              parsed_user = parse_regex(message, r'acct="(?P<user>[^"]+)"') ?? {}
              if exists(parsed_user.user) { .user = parsed_user.user }

              parsed_addr = parse_regex(message, r'addr=(?P<ip>[\d.]+)') ?? {}
              if exists(parsed_addr.ip) { .source_ip = parsed_addr.ip }
            }
          '';
        };

        # Filter out "other" events to reduce noise
        filter_ssh = {
          type = "filter";
          inputs = ["parse_ssh"];
          condition = ".event != \"other\"";
        };

        filter_audit = {
          type = "filter";
          inputs = ["parse_audit"];
          condition = ".event != \"other\"";
        };

        tag_metrics = {
          type = "remap";
          inputs = ["host_metrics" "network_stats"];
          source = ''
            .host = "${hostName}"
          '';
        };
      };

      sinks = lib.mkMerge [
        (lib.mkIf (!isSystemCollector) {
          # SSH logs to Loki
          ssh_logs_remote = {
            type = "loki";
            inputs = ["filter_ssh"];
            endpoint = "http://${systemCollector}:3100";
            encoding.codec = "json";
            labels = {
              host = "{{ host }}";
              log_type = "{{ log_type }}";
              event = "{{ event }}";
              user = "{{ user }}";
            };
            batch = {
              max_bytes = 1048576;
              timeout_secs = 10;
            };
          };

          # Audit logs to Loki
          audit_logs_remote = {
            type = "loki";
            inputs = ["filter_audit"];
            endpoint = "http://${systemCollector}:3100";
            encoding.codec = "json";
            labels = {
              host = "{{ host }}";
              log_type = "{{ log_type }}";
              event = "{{ event }}";
              user = "{{ user }}";
            };
            batch = {
              max_bytes = 1048576;
              timeout_secs = 10;
            };
          };

          # Metrics to Prometheus
          system_metrics_remote = {
            type = "prometheus_remote_write";
            inputs = ["tag_metrics"];
            endpoint = "http://${systemCollector}:9090/api/v1/write";
            batch.timeout_secs = 10;
            healthcheck.enabled = false;
          };
        })
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/vector 0700 vector vector - -"
  ];
  # Vector permissions
  systemd.services.vector.serviceConfig = {
    SupplementaryGroups = ["systemd-journal"];
    MemoryMax = "256M";
    CPUQuota = "30%";
  };

  # networking.firewall.interfaces."wg-mgnt".allowedTCPPorts = [];
}
