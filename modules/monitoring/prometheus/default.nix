# Prometheus alertmanager and rules configuration
# Note: Prometheus server itself is configured in vector/monitor-systems.nix
{ config, ... }:
let
  wgAdminAddr = config.networking.sbee.currentHost.wg-admin;
in
{
  imports = [
    ./rules.nix
  ];

  # TODO: enable alertmanager when ntfy integration is ready
  services.prometheus.alertmanager = {
    enable = false;
    listenAddress = wgAdminAddr;
    port = 9093;
  };

  # Open firewall for alertmanager (when enabled)
  # networking.firewall.interfaces."wg-admin".allowedTCPPorts = [9093];
}
