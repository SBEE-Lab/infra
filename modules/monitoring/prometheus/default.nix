# Prometheus alertmanager and rules configuration
# Note: Prometheus server itself is configured in vector/monitor-systems.nix
{ config, ... }:
let
  wgMgntAddr = config.networking.sbee.currentHost.wg-mgnt;
in
{
  imports = [
    ./rules.nix
  ];

  # TODO: enable alertmanager when ntfy integration is ready
  services.prometheus.alertmanager = {
    enable = false;
    listenAddress = wgMgntAddr;
    port = 9093;
  };

  # Open firewall for alertmanager (when enabled)
  # networking.firewall.interfaces."wg-mgnt".allowedTCPPorts = [9093];
}
