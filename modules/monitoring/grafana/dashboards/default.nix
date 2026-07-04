# Provisioned Grafana dashboards
# - infra.nix: high-level overview (Grafana home)
# - hosts.nix: host/resource and tailnet node health
# - apps.nix: user-facing app smoke/access status
# - jobs.nix: batch/sync/backup status
# - access-audit.nix: SSH / Authentik / Headscale audit drilldown
# - ai-resources.nix: AI/GPU-facing service status
{
  pkgs,
  lib,
  ...
}:
let
  datasources = {
    prometheus = {
      type = "prometheus";
      uid = "PBFA97CFB590B2093";
    };
    loki = {
      type = "loki";
      uid = "P8E80F9AEF21F6940";
    };
  };

  dashboards = {
    sjanglab-infra = import ./infra.nix { inherit datasources; };
    sjanglab-hosts = import ./hosts.nix { inherit datasources; };
    sjanglab-apps = import ./apps.nix { inherit datasources; };
    sjanglab-jobs = import ./jobs.nix { inherit datasources; };
    sjanglab-access-audit = import ./access-audit.nix { inherit datasources; };
    sjanglab-ai-resources = import ./ai-resources.nix { inherit datasources; };
  };

  dashboardsDir = pkgs.runCommand "grafana-dashboards" { } (
    ''
      mkdir -p $out
    ''
    + lib.concatStrings (
      lib.mapAttrsToList (name: dashboard: ''
        ${lib.getExe pkgs.jq} . ${pkgs.writeText "${name}-dashboard.json" (builtins.toJSON dashboard)} > $out/${name}.json
      '') dashboards
    )
  );
in
{
  services.grafana.settings.dashboards.default_home_dashboard_path =
    "${dashboardsDir}/sjanglab-infra.json";

  services.grafana.provision.dashboards.settings = {
    apiVersion = 1;
    providers = [
      {
        name = "infra";
        type = "file";
        disableDeletion = true;
        updateIntervalSeconds = 30;
        allowUiUpdates = false;
        options.path = dashboardsDir;
      }
    ];
  };
}
