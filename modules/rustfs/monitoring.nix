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
  metricsCollector = config.networking.sbee.hosts.rho.wg-admin;
  hasGatusCheck = monitoring.hasOption options [
    "gatusCheck"
    "push"
  ];
in
{
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions =
          lib.optional cfg.monitoring.gatus.enable (
            monitoring.requireOption {
              inherit options;
              path = [
                "gatusCheck"
                "push"
              ];
              consumer = "services.rustfs.monitoring.gatus";
              module = "modules/gatus/check.nix";
            }
          )
          ++ lib.optional cfg.monitoring.loki.enable {
            assertion = config.services.vector.enable;
            message = "services.rustfs.monitoring.loki requires services.vector.enable = true";
          };
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

      (lib.mkIf cfg.monitoring.loki.enable {
        services.vector.settings = monitoring.mkJournaldLokiPipeline {
          name = "rustfs";
          hostName = config.networking.hostName;
          endpoint = "http://${metricsCollector}:3100";
          units = [
            "rustfs.service"
            "rustfs-bootstrap.service"
          ];
        };
      })
    ]
  );
}
