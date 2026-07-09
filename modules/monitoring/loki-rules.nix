{
  config,
  lib,
  pkgs,
  ...
}:
let
  wgAdminAddr = config.networking.sbee.hosts.rho.wg-admin;

  opsCritical = {
    severity = "critical";
    alert_category = "ops";
    service = "backup-jobs";
  };

  opsWarning = opsCritical // {
    severity = "warning";
  };

  auditWarning = {
    severity = "warning";
    alert_category = "audit";
  };

  mkAlert =
    {
      alert,
      expr,
      for,
      labels,
      summary,
      description,
    }:
    {
      inherit
        alert
        expr
        for
        labels
        ;
      annotations = {
        inherit summary description;
      };
    };

  rules = {
    groups = [
      {
        name = "systemd_job_alerts";
        interval = "60s";
        rules = [
          (mkAlert {
            alert = "BackupJobFailed";
            expr = ''
              sum by (host, unit, job_class) (
                count_over_time(
                  {log_type="systemd_status", event="job_snapshot"}
                  | json
                  | alert_enabled = "true"
                  | health = "FAIL"
                [10m])
              ) > 0
            '';
            for = "15m";
            labels = opsCritical;
            summary = "Backup job failed";
            description = "{{ $labels.host }} {{ $labels.unit }} has a failed systemd snapshot";
          })
          (mkAlert {
            alert = "BackupJobStale";
            expr = ''
              sum by (host, unit, job_class) (
                count_over_time(
                  {log_type="systemd_status", event="job_snapshot"}
                  | json
                  | alert_enabled = "true"
                  | health = "WARN"
                  | health_reason = "stale_success"
                [30m])
              ) > 0
            '';
            for = "30m";
            labels = opsWarning;
            summary = "Backup job stale";
            description = "{{ $labels.host }} {{ $labels.unit }} has exceeded its success freshness window";
          })
        ];
      }
      {
        name = "audit_log_alerts";
        interval = "60s";
        rules = [
          (mkAlert {
            alert = "SshLoginFailureBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="ssh", event="login_failed"}[10m])
              ) > 10
            '';
            for = "5m";
            labels = auditWarning;
            summary = "SSH login failure burst";
            description = "{{ $labels.host }} observed more than 10 SSH login failures in 10 minutes";
          })
          (mkAlert {
            alert = "AuthentikLoginFailureBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="authentik", event="login_failed"}[10m])
              ) > 10
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Authentik login failure burst";
            description = "{{ $labels.host }} observed more than 10 Authentik login failures in 10 minutes";
          })
          (mkAlert {
            alert = "AuthentikForwardAuthDenyBurst";
            expr = ''
              sum by (host) (
                count_over_time({log_type="authentik", event="forward_auth_deny"}[10m])
              ) > 50
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Authentik forward-auth denial burst";
            description = "{{ $labels.host }} observed more than 50 forward-auth denials in 10 minutes";
          })
          (mkAlert {
            alert = "HeadscaleOidcDenied";
            expr = ''
              sum by (host) (
                count_over_time({log_type="headscale", event="oidc_denied"}[10m])
              ) > 0
            '';
            for = "1m";
            labels = auditWarning;
            summary = "Headscale OIDC access denied";
            description = "{{ $labels.host }} logged a Headscale OIDC denial";
          })
          (mkAlert {
            alert = "HeadscaleNodeExpired";
            expr = ''
              max by (host) (
                max_over_time(
                  {log_type="headscale_nodes", event="nodes_summary"}
                  | json
                  | unwrap expired_count
                [15m])
              ) > 0
            '';
            for = "5m";
            labels = auditWarning;
            summary = "Headscale node expired";
            description = "{{ $labels.host }} reports one or more expired Headscale nodes";
          })
        ];
      }
    ];
  };

  rulesYaml = builtins.toJSON rules;
in
{
  services.loki.configuration.ruler = {
    enable_api = true;
    alertmanager_url = "http://${wgAdminAddr}:9093/alertmanager";
    enable_alertmanager_v2 = true;
    rule_path = "/var/lib/loki/rules-tmp";
    storage = {
      type = "local";
      local.directory = pkgs.writeTextDir "fake/sjanglab-alerts.yaml" rulesYaml;
    };
  };

  systemd.tmpfiles.rules = lib.mkIf config.services.loki.enable [
    "d /var/lib/loki/rules-tmp 0700 loki loki - -"
  ];
}
