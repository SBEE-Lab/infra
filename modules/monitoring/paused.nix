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

  gatusCheck.push = lib.mkForce [ ];
  services.sbee.systemdStatusExporter.enable = lib.mkForce false;

  systemd.services = disableUnits ([ "vector" ] ++ hostUnits.${config.networking.hostName});
  systemd.timers = disableUnits (hostTimers.${config.networking.hostName} or [ ]);
}
