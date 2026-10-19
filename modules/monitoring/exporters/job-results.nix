{
  config,
  lib,
  pkgs,
  ...
}:
let
  host = config.networking.hostName;
  borgJobs = lib.mapAttrs' (
    name: job:
    lib.nameValuePair "borgbackup-job-${name}" {
      scheduled = job.startAt != [ ] && job.startAt != "";
    }
  ) config.services.borgbackup.jobs;
  pg = config.services.postgresqlBackup;
  pgJobs =
    lib.genAttrs
      (
        if !pg.enable then
          [ ]
        else if pg.backupAll then
          [ "postgresqlBackup" ]
        else
          map (database: "postgresqlBackup-${database}") pg.databases
      )
      (_: {
        scheduled = pg.startAt != [ ] && pg.startAt != "";
      });
  jobs = borgJobs // pgJobs;
  statePath = unit: "/var/lib/infra-job-results/${unit}/state.json";
  sourceName = unit: "job_${lib.sbee.monitoring.componentId unit}_source";
  metricName = unit: "job_${lib.sbee.monitoring.componentId unit}_metrics";
  fields = [
    "last_completion_timestamp_seconds"
    "last_result"
  ];
in
{
  systemd.services = lib.mapAttrs (unit: _: {
    serviceConfig = {
      StateDirectory = "infra-job-results/${unit}";
      StateDirectoryMode = "0755";
      # Telemetry failures must not prevent or change the outcome of a backup.
      ExecStopPost = [
        "-${pkgs.writeShellScript "job-result-${unit}" ''
          umask 022
          result=0; test "$SERVICE_RESULT" = success || result=1
          printf '{"last_completion_timestamp_seconds":%s,"last_result":%s}\n' "$(${pkgs.coreutils}/bin/date +%s)" "$result" > ${lib.escapeShellArg (statePath unit)}
        ''}"
      ];
    };
  }) jobs;

  services.vector.settings = lib.mkIf (jobs != { }) {
    sources = lib.mapAttrs' (
      unit: _:
      lib.nameValuePair (sourceName unit) {
        type = "exec";
        mode = "scheduled";
        scheduled.exec_interval_secs = 60;
        command = [
          pkgs.runtimeShell
          "-c"
          "test ! -e ${lib.escapeShellArg (statePath unit)} || exec ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg (statePath unit)}"
        ];
        decoding.codec = "json";
      }
    ) jobs;
    transforms = lib.mapAttrs' (
      unit: job:
      lib.nameValuePair (metricName unit) {
        type = "log_to_metric";
        inputs = [ (sourceName unit) ];
        metrics = map (field: {
          type = "gauge";
          inherit field;
          name = "infra_job_${field}";
          tags = {
            inherit host;
            unit = "${unit}.service";
            scheduled = if job.scheduled then "true" else "false";
          };
        }) fields;
      }
    ) jobs;
    sinks.${if host == "rho" then "system_metrics_local" else "system_metrics_remote"}.inputs =
      map metricName (lib.attrNames jobs);
  };
}
