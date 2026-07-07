{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.services.rustfs;
  monitoring = lib.sbee.monitoring;
  endpoint = "http://${cfg.listenAddress}:${toString cfg.apiPort}";
  hasGatusCheck = monitoring.hasOption options [
    "gatusCheck"
    "push"
  ];
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = lib.optional cfg.monitoring.gatus.enable (
          monitoring.requireOption {
            inherit options;
            path = [
              "gatusCheck"
              "push"
            ];
            consumer = "services.rustfs.monitoring.gatus";
            module = "modules/gatus/check.nix";
          }
        );
      }

      (lib.mkIf (cfg.monitoring.gatus.enable && hasGatusCheck) {
        gatusCheck.push = [
          (monitoring.mkGatusHttpCheck {
            name = "RustFS ${config.networking.hostName}";
            group = "storage";
            url = "${endpoint}/health/ready";
          })
        ];
      })
    ]
  );
}
