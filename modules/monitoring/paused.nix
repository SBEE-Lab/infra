# Keep monitoring configuration and service accounts intact for a reversible pause.
{ config, lib, ... }:
let
  hostUnits = {
    eta = [
      "gatus"
      "prometheus-blackbox-exporter"
      "prometheus-nginx-exporter"
    ];
    psi = [
      "prometheus-nvidia-gpu-exporter"
      "prometheus-restic-exporter"
    ];
    rho = [
      "alertmanager"
      "grafana"
      "loki"
      "prometheus"
      "prometheus-postgres-exporter"
      "postgresql-replication-audit"
      "ssh-access-audit"
      "tailnet-app-access-audit"
    ];
    tau = [
      "loki"
      "prometheus-postgres-exporter"
      "postgresql-replication-audit"
    ];
  };
  hostTimers = {
    rho = [
      "postgresql-replication-audit"
      "ssh-access-audit"
      "tailnet-app-access-audit"
    ];
    tau = [ "postgresql-replication-audit" ];
  };
  disableUnits =
    names:
    lib.genAttrs names (_: {
      enable = lib.mkForce false;
    });
in
{
  imports = [
    ../gatus/check.nix
    ./exporters/systemd-status.nix
  ];

  config = lib.mkMerge [
    {
      # Persistent job results replace repeated snapshots as the alert input.
      services.sbee.systemdStatusExporter.enable = lib.mkForce false;
    }
    (lib.mkIf (config.services.sbee.monitoring.mode == "paused") {
      gatusCheck.push = lib.mkForce [ ];
      systemd.services = disableUnits (
        [
          "vector"
          "prometheus-node-exporter"
          "prometheus-smartctl-exporter"
        ]
        ++ hostUnits.${config.networking.hostName}
      );
      systemd.timers = disableUnits (hostTimers.${config.networking.hostName} or [ ]);
    })
  ];
}
