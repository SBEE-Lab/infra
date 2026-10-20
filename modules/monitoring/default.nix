{ lib, ... }:
{
  imports = [
    ./paused.nix
    ./exporters/job-results.nix
    ./exporters/storage.nix
  ];

  options.services.sbee.monitoring.mode = lib.mkOption {
    type = lib.types.enum [
      "paused"
      "observe"
      "active"
    ];
    default = "paused";
    description = ''
      paused stops monitoring units; observe collects and evaluates without
      outbound notifications; active enables explicitly routed notifications.
      External watchdog maintenance must be managed separately.
    '';
  };
}
