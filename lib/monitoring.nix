{ lib }:
let
  optionPathToString = lib.concatStringsSep ".";

  hasOption = options: path: lib.hasAttrByPath path options;

  hostRegex = hosts: lib.concatStringsSep "|" hosts;

  componentId =
    value: lib.replaceStrings [ "." "@" "-" "/" ":" " " ] [ "_" "_" "_" "_" "_" "_" ] value;

  mkVectorLokiSink =
    {
      input,
      endpoint,
      labels,
      batch ? null,
    }:
    {
      type = "loki";
      inputs = [ input ];
      inherit endpoint labels;
      encoding.codec = "json";
    }
    // lib.optionalAttrs (batch != null) {
      inherit batch;
    };

  routeValues =
    values: includeOther: otherValue:
    values ++ lib.optional (includeOther && !(builtins.elem otherValue values)) otherValue;

  routeInputName = name: value: "${name}_${componentId value}";

  mkVectorFieldFilters =
    {
      name,
      input,
      field,
      values,
      includeOther ? true,
      otherValue ? "other",
    }:
    let
      otherCondition = ''!includes(${builtins.toJSON values}, (to_string(.${field}) ?? ""))'';
    in
    lib.listToAttrs (
      map (value: {
        name = routeInputName name value;
        value = {
          type = "filter";
          inputs = [ input ];
          condition =
            if includeOther && value == otherValue then
              otherCondition
            else
              ''(to_string(.${field}) ?? "") == ${builtins.toJSON value}'';
        };
      }) (routeValues values includeOther otherValue)
    );

  mkVectorRoutedLokiSinks =
    {
      name,
      routeName ? name,
      endpoint,
      values,
      labelsFor,
      batch ? null,
      includeOther ? true,
      otherValue ? "other",
    }:
    lib.listToAttrs (
      map (value: {
        name = "${name}_${componentId value}_loki";
        value = mkVectorLokiSink {
          input = routeInputName routeName value;
          inherit endpoint batch;
          labels = labelsFor value;
        };
      }) (routeValues values includeOther otherValue)
    );

  mkVectorRoutedLokiPipeline =
    {
      name,
      input,
      field,
      values,
      endpoint,
      labelsFor,
      batch ? null,
      includeOther ? true,
      otherValue ? "other",
    }:
    {
      transforms = mkVectorFieldFilters {
        inherit
          name
          input
          field
          values
          includeOther
          otherValue
          ;
      };
      sinks = mkVectorRoutedLokiSinks {
        inherit
          name
          endpoint
          values
          labelsFor
          batch
          includeOther
          otherValue
          ;
      };
    };
in
{
  inherit
    hasOption
    componentId
    mkVectorLokiSink
    mkVectorFieldFilters
    mkVectorRoutedLokiSinks
    mkVectorRoutedLokiPipeline
    ;

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

  mkSystemdJobSpec =
    {
      unit,
      jobClass,
      triggerKind,
      alertEnabled ? true,
      maxSuccessAgeSeconds ? null,
    }:
    {
      inherit
        unit
        jobClass
        triggerKind
        alertEnabled
        ;
    }
    // lib.optionalAttrs (maxSuccessAgeSeconds != null) {
      inherit maxSuccessAgeSeconds;
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
    let
      routed = mkVectorRoutedLokiPipeline {
        name = "${name}_logs";
        input = "${name}_logs";
        field = "unit";
        values = units;
        inherit endpoint;
        includeOther = false;
        labelsFor = unit: {
          host = hostName;
          inherit service unit;
        };
        batch = {
          max_bytes = maxBatchBytes;
          timeout_secs = batchTimeoutSecs;
        };
      };
    in
    {
      sources."${name}_journald" = {
        type = "journald";
        include_units = units;
      };

      transforms = {
        "${name}_logs" = {
          type = "remap";
          inputs = [ "${name}_journald" ];
          source = ''
            .host = "${hostName}"
            .service = "${service}"
            .unit = to_string(._SYSTEMD_UNIT) ?? "unknown"
            .message = to_string(.message) ?? ""
          '';
        };
      }
      // routed.transforms;

      inherit (routed) sinks;
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
      annotations ? { },
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
        annotations = annotations // {
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
        annotations = annotations // {
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
        annotations = annotations // {
          summary = "${summaryPrefix} critically low on space";
          description = "{{ $labels.host }}: {{ $value | humanize }}% free on ${mountpoint}";
        };
      }
    ];
}
