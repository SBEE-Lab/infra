{ config, lib, ... }:
{
  imports = [ ../monitoring/exporters/systemd-status.nix ];

  services.sbee.systemdStatusExporter = {
    enable = lib.mkDefault config.services.vector.enable;
    units = map (
      name:
      lib.sbee.monitoring.mkSystemdJobSpec {
        unit = "acme-order-renew-${name}.service";
        jobClass = "acme";
        triggerKind = "timer";
      }
    ) (lib.attrNames config.security.acme.certs);
  };

  security.acme = {
    defaults.email = "sjang.bioe@gmail.com";
    acceptTerms = true;
  };

  sops.secrets.cloudflare-credentials = {
    sopsFile = ./secrets.yaml;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };
}
