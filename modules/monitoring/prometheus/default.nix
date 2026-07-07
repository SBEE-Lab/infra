# Prometheus alertmanager and rules configuration
# Note: Prometheus server itself is configured in vector/monitor-systems.nix
{ ... }:
{
  imports = [
    ./alertmanager.nix
    ./rules.nix
  ];
}
