{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sbee.systemdStatusExporter;
  sourceName = "${cfg.host}_systemd_status_source";
  sinkName = "${cfg.host}_systemd_status_loki";

  unitSpecType = lib.types.submodule {
    options = {
      unit = lib.mkOption {
        type = lib.types.str;
        description = "Systemd service unit to snapshot.";
      };

      jobClass = lib.mkOption {
        type = lib.types.str;
        default = "unknown";
        description = "Bounded job class emitted as job_class.";
      };

      triggerKind = lib.mkOption {
        type = lib.types.str;
        default = "unknown";
        description = "How the job is normally triggered; emitted as trigger_kind.";
      };

      alertEnabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether Loki alert rules should evaluate this unit.";
      };

      maxSuccessAgeSeconds = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Maximum age for the last successful service run before WARN.";
      };
    };
  };

  normalizeUnit =
    unit:
    if builtins.isString unit then
      {
        inherit unit;
        job_class = "unknown";
        trigger_kind = "unknown";
        alert_enabled = false;
        max_success_age_seconds = cfg.maxSuccessAgeSeconds;
      }
    else
      {
        inherit (unit) unit;
        job_class = unit.jobClass;
        trigger_kind = unit.triggerKind;
        alert_enabled = unit.alertEnabled;
        max_success_age_seconds =
          if unit.maxSuccessAgeSeconds == null then cfg.maxSuccessAgeSeconds else unit.maxSuccessAgeSeconds;
      };

  systemdStatusScript = pkgs.writeShellScript "${cfg.host}-systemd-status" ''
    exec ${pkgs.python3}/bin/python3 ${./systemd-status-exporter.py} \
      --host ${lib.escapeShellArg cfg.host} \
      --units-json ${lib.escapeShellArg (builtins.toJSON (map normalizeUnit cfg.units))} \
      --systemctl ${pkgs.systemd}/bin/systemctl
  '';
in
{
  options.services.sbee.systemdStatusExporter = {
    enable = lib.mkEnableOption "scheduled systemd unit status snapshots via Vector";

    host = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Host label written to systemd status events.";
    };

    units = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str unitSpecType);
      default = [ ];
      description = "Systemd service units or unit specs to snapshot.";
    };

    maxSuccessAgeSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 45 * 24 * 3600;
      description = "Default maximum age for the last successful service run before WARN.";
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Vector exec source interval.";
    };

    lokiEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://${config.networking.sbee.hosts.rho.wg-admin}:3100";
      description = "Loki endpoint receiving systemd status events.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.vector.enable;
        message = "services.sbee.systemdStatusExporter requires services.vector.enable = true";
      }
    ];

    services.vector.settings = {
      sources.${sourceName} = {
        type = "exec";
        command = [ (toString systemdStatusScript) ];
        mode = "scheduled";
        scheduled.exec_interval_secs = cfg.intervalSeconds;
        decoding.codec = "json";
      };

      sinks.${sinkName} = {
        type = "loki";
        inputs = [ sourceName ];
        endpoint = cfg.lokiEndpoint;
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          log_type = "{{ log_type }}";
          event = "{{ event }}";
        };
        batch.timeout_secs = 10;
      };
    };
  };
}
