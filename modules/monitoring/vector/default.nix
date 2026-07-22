# Vector agent configuration for log/metrics collection
# - Collects sshd logs with user/IP extraction
# - Collects auditd session events for correlation
# - Streams to central Loki/Prometheus on rho
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.networking) hostName;

  systemCollector = config.networking.sbee.hosts.rho.wg-admin;
  isSystemCollector = hostName == "rho";

  monitoring = lib.sbee.monitoring;
  sshEvents = [
    "login_success"
    "login_failed"
    "session_closed"
    "session_opened"
    "disconnected"
  ];
  auditEvents = [
    "session_start"
    "session_end"
    "auth_attempt"
  ];
  ingressNetworks = [
    "unknown"
    "tailnet"
    "wg-admin"
    "public"
  ];
  lokiEndpoint =
    if isSystemCollector then "http://127.0.0.1:3100" else "http://${systemCollector}:3100";
  lokiBatch = {
    max_bytes = 1048576;
    timeout_secs = 10;
  };

  netStatsScript = pkgs.writeShellScript "net-stats.sh" ''
    #!/usr/bin/env bash
    for iface in /sys/class/net/*; do
      name=$(basename "$iface")
      [[ "$name" =~ ^(lo|veth|docker|br-) ]] && continue

      echo "{\"interface\":\"$name\",\"rx_bytes\":$(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0),\"tx_bytes\":$(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0),\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    done
  '';
in
{
  imports = [
    ../auditd.nix
    ../nginx-access-logs.nix
  ];

  services.vector = {
    enable = true;

    settings = {
      sources = {
        sshd_logs = {
          type = "journald";
          include_units = [ "sshd" ];
        };

        # Audit logs for session tracking
        audit_logs = {
          type = "journald";
          include_units = [ "auditd" ];
        };

        host_metrics = {
          type = "host_metrics";
          scrape_interval_secs = 60;
          collectors = [
            "cpu"
            "disk"
            "filesystem"
            "memory"
            "network"
          ];
          filesystem.mountpoints.excludes = [
            "/etc/group"
            "/etc/hostname"
            "/etc/hosts"
            "/etc/passwd"
            "/etc/resolv.conf"
            "/etc/shadow"
            "/run/credentials/*"
            "/run/docker/netns/*"
            "/var/lib/docker/overlay2/*/merged"
          ];
        };

        network_stats = {
          type = "exec";
          command = [ "${netStatsScript}" ];
          mode = "scheduled";
          scheduled.exec_interval_secs = 60;
          decoding.codec = "json";
        };

        nginx_access_logs = {
          type = "file";
          include = [ "/var/log/nginx/access-audit/*.log" ];
          read_from = "end";
        };
      };

      transforms = {
        # Parse SSH logs - extract user, IP, port, auth method, and key metadata
        parse_ssh = {
          type = "remap";
          inputs = [ "sshd_logs" ];
          source = ''
            .host = "${hostName}"
            .log_type = "ssh"

            message = string!(.message)
            .event = "other"

            # Accepted publickey for alice from 203.0.113.50 port 52431 ssh2: ED25519 SHA256:abc
            # Failed password for invalid user bob from 2001:db8::1 port 22 ssh2
            if match(message, r'(Accepted|Failed)') {
              parsed = parse_regex(message, r'(?P<status>Accepted|Failed) (?P<method>\w+) for (?:invalid user )?(?P<user>\S+) from (?P<ip>\S+) port (?P<port>\d+)(?: ssh2(?:: (?P<key_type>\S+) (?P<key_fingerprint>SHA256:\S+))?)?') ?? {}

              if exists(parsed.status) {
                .user = parsed.user
                .source_ip = parsed.ip
                .source_port = parsed.port
                .auth_method = parsed.method

                if exists(parsed.key_type) {
                  .key_type = parsed.key_type
                }
                if exists(parsed.key_fingerprint) {
                  .key_fingerprint = parsed.key_fingerprint
                }

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
          inputs = [ "audit_logs" ];
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
          inputs = [ "parse_ssh" ];
          condition = ".event != \"other\"";
        };

        filter_audit = {
          type = "filter";
          inputs = [ "parse_audit" ];
          condition = ".event != \"other\"";
        };

        tag_metrics = {
          type = "remap";
          inputs = [
            "host_metrics"
            "network_stats"
          ];
          source = ''
            .host = "${hostName}"
          '';
        };

        parse_nginx_access = {
          type = "remap";
          inputs = [ "nginx_access_logs" ];
          source = ''
            parsed = parse_json(to_string(.message) ?? "{}") ?? {}

            .log_type = "nginx_access"
            .system_host = "${hostName}"

            .time = to_string(parsed.time) ?? ""
            .host = to_string(parsed.host) ?? "unknown"
            .service = to_string(parsed.service) ?? "unknown"
            .source_ip = to_string(parsed.source_ip) ?? "unknown"
            .status = to_int(parsed.status) ?? 0
            .http_method = to_string(parsed.http_method) ?? "unknown"
            .request_path = to_string(parsed.request_path) ?? ""
            .user_agent = to_string(parsed.user_agent) ?? ""
            .request_id = to_string(parsed.request_id) ?? ""
            .bytes_sent = to_int(parsed.bytes_sent) ?? 0
            .request_time = to_float(parsed.request_time) ?? 0.0
            .protocol = to_string(parsed.protocol) ?? ""

            .ingress_network = "unknown"
            if .source_ip != "unknown" && .source_ip != "" {
              if (ip_cidr_contains("100.64.0.0/10", .source_ip) ?? false) {
                .ingress_network = "tailnet"
              } else if (ip_cidr_contains("10.100.0.0/24", .source_ip) ?? false) {
                .ingress_network = "wg-admin"
              } else {
                .ingress_network = "public"
              }
            }
          '';
        };
      }
      // monitoring.mkVectorFieldFilters {
        name = "ssh_logs";
        input = "filter_ssh";
        field = "event";
        values = sshEvents;
      }
      // monitoring.mkVectorFieldFilters {
        name = "audit_logs";
        input = "filter_audit";
        field = "event";
        values = auditEvents;
      }
      // monitoring.mkVectorFieldFilters {
        name = "nginx_access_logs";
        input = "parse_nginx_access";
        field = "ingress_network";
        values = ingressNetworks;
      };

      sinks =
        monitoring.mkVectorRoutedLokiSinks {
          name = "ssh_logs";
          endpoint = lokiEndpoint;
          values = sshEvents;
          batch = lokiBatch;
          labelsFor = event: {
            host = hostName;
            inherit event;
            log_type = "ssh";
          };
        }
        // monitoring.mkVectorRoutedLokiSinks {
          name = "audit_logs";
          endpoint = lokiEndpoint;
          values = auditEvents;
          batch = lokiBatch;
          labelsFor = event: {
            host = hostName;
            inherit event;
            log_type = "audit";
          };
        }
        // monitoring.mkVectorRoutedLokiSinks {
          name = "nginx_access_logs";
          endpoint = lokiEndpoint;
          values = ingressNetworks;
          batch = lokiBatch;
          labelsFor = ingressNetwork: {
            system_host = hostName;
            log_type = "nginx_access";
            ingress_network = ingressNetwork;
          };
        }
        // lib.optionalAttrs isSystemCollector {
          system_metrics_local = {
            type = "prometheus_exporter";
            inputs = [ "tag_metrics" ];
            address = "127.0.0.1:9598";
          };
        }
        // lib.optionalAttrs (!isSystemCollector) {
          system_metrics_remote = {
            type = "prometheus_remote_write";
            inputs = [ "tag_metrics" ];
            endpoint = "http://${systemCollector}:9090/api/v1/write";
            batch.timeout_secs = 10;
            healthcheck.enabled = false;
          };
        };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/vector 0700 vector vector - -"
  ];
  # Vector permissions
  systemd.services.vector.serviceConfig = {
    SupplementaryGroups = [
      "systemd-journal"
    ]
    ++ lib.optional config.services.nginx.enable config.services.nginx.group;
    MemoryMax = "256M";
    CPUQuota = "30%";
  };
}
