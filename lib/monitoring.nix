{ lib }:
let
  optionPathToString = lib.concatStringsSep ".";

  hasOption = options: path: lib.hasAttrByPath path options;

  hostRegex = hosts: lib.concatStringsSep "|" hosts;
in
{
  inherit hasOption;

  requireOption =
    {
      options,
      path,
      consumer,
      module ? null,
    }:
    {
      assertion = hasOption options path;
      message =
        "${consumer} requires NixOS option ${optionPathToString path}"
        + lib.optionalString (module != null) "; import ${module}";
    };

  mkGatusHttpCheck =
    {
      name,
      group,
      url,
    }:
    {
      inherit name group url;
    };

  mkJournaldLokiPipeline =
    {
      name,
      hostName,
      endpoint,
      units,
      service ? name,
      maxBatchBytes ? 1048576,
      batchTimeoutSecs ? 10,
    }:
    {
      sources."${name}_journald" = {
        type = "journald";
        include_units = units;
      };

      transforms."${name}_logs" = {
        type = "remap";
        inputs = [ "${name}_journald" ];
        source = ''
          .host = "${hostName}"
          .service = "${service}"
          .unit = to_string(._SYSTEMD_UNIT) ?? "unknown"
          .message = to_string(.message) ?? ""
        '';
      };

      sinks."${name}_logs_loki" = {
        type = "loki";
        inputs = [ "${name}_logs" ];
        inherit endpoint;
        encoding.codec = "json";
        labels = {
          host = "{{ host }}";
          service = "{{ service }}";
          unit = "{{ unit }}";
        };
        batch = {
          max_bytes = maxBatchBytes;
          timeout_secs = batchTimeoutSecs;
        };
      };
    };

  mkFilesystemFreeSpaceAlerts =
    {
      alertPrefix,
      hosts,
      mountpoint,
      warningFreePercent,
      criticalFreePercent,
      warningLabels,
      criticalLabels,
      freshnessLabels ? warningLabels,
      freshnessWindow ? "10m",
      freshnessFor ? "5m",
      warningFor ? "10m",
      criticalFor ? "5m",
      summaryPrefix ? alertPrefix,
    }:
    let
      hostsRe = hostRegex hosts;
      freshnessRules = map (host: {
        alert = "${alertPrefix}MetricsMissing";
        expr = ''absent_over_time(host_filesystem_total_bytes{host="${host}",mountpoint="${mountpoint}"}[${freshnessWindow}])'';
        for = freshnessFor;
        labels = freshnessLabels // {
          inherit host;
        };
        annotations = {
          summary = "${summaryPrefix} metrics missing";
          description = "${host}: no ${mountpoint} filesystem metrics received for ${freshnessWindow}";
        };
      }) hosts;
    in
    freshnessRules
    ++ [
      {
        alert = "${alertPrefix}SpaceLow";
        expr = ''
          (
            host_filesystem_free_bytes{host=~"${hostsRe}",mountpoint="${mountpoint}"} /
            host_filesystem_total_bytes{host=~"${hostsRe}",mountpoint="${mountpoint}"}
          ) * 100 < ${toString warningFreePercent}
        '';
        for = warningFor;
        labels = warningLabels;
        annotations = {
          summary = "${summaryPrefix} low on space";
          description = "{{ $labels.host }}: {{ $value | humanize }}% free on ${mountpoint}";
        };
      }

      {
        alert = "${alertPrefix}SpaceCritical";
        expr = ''
          (
            host_filesystem_free_bytes{host=~"${hostsRe}",mountpoint="${mountpoint}"} /
            host_filesystem_total_bytes{host=~"${hostsRe}",mountpoint="${mountpoint}"}
          ) * 100 < ${toString criticalFreePercent}
        '';
        for = criticalFor;
        labels = criticalLabels;
        annotations = {
          summary = "${summaryPrefix} critically low on space";
          description = "{{ $labels.host }}: {{ $value | humanize }}% free on ${mountpoint}";
        };
      }
    ];
}
