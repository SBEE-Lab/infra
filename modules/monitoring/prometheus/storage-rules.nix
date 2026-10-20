{ lib, ... }:
let
  # Count arrays rather than relying on kernel-assigned md device numbers.
  expectedArrays = {
    psi = 2;
    rho = 1;
    tau = 1;
  };
  rule =
    {
      alert,
      expr,
      summary,
      description,
      critical ? false,
      observation ? false,
      duration ? "15m",
      labels ? { },
    }:
    {
      inherit alert expr;
      for = duration;
      labels = {
        severity = if critical then "critical" else "warning";
        response = if critical then "immediate" else "business-hours";
        signal = if observation then "collection" else "storage";
      }
      // labels;
      annotations = { inherit summary description; };
    };
in
{
  # Each rule file must be one document; NixOS concatenates inline rules.
  services.prometheus.ruleFiles = [
    (builtins.toFile "storage.rules" (
      builtins.toJSON {
        groups = [
          {
            name = "storage_alerts";
            interval = "60s";
            rules = [
              (rule {
                alert = "RAIDDegraded";
                expr = "node_md_degraded > 0";
                critical = true;
                duration = "5m";
                summary = "RAID redundancy is degraded";
                description = "{{ $labels.host }} {{ $labels.device }} has missing RAID members. Inspect /proc/mdstat and map /dev/md/data before arranging replacement; do not recreate the array.";
              })
              (rule {
                alert = "RAIDInactive";
                expr = ''node_md_state{state="inactive"} == 1'';
                critical = true;
                duration = "5m";
                summary = "RAID array is inactive";
                description = "{{ $labels.host }} {{ $labels.device }} is inactive. Check affected mounts and array members before attempting assembly; do not initialize or recreate it.";
              })
              (rule {
                alert = "DiskSMARTFailed";
                expr = "smartctl_device_smart_status == 0";
                critical = true;
                duration = "5m";
                summary = "Disk reports failed SMART health";
                description = "{{ $labels.host }} {{ $labels.device }} reports failed SMART health. Identify the disk, check backup availability and RAID membership, and arrange replacement.";
              })
              (rule {
                alert = "NVMeCriticalWarning";
                expr = "smartctl_device_critical_warning > 0";
                critical = true;
                duration = "5m";
                summary = "NVMe reports a critical warning";
                description = "{{ $labels.host }} {{ $labels.device }} reports NVMe warning bits {{ $value }}. Inspect the warning and affected data; check backup availability before maintenance.";
              })
              (rule {
                alert = "DiskUncorrectableSectors";
                expr = ''smartctl_device_attribute{attribute_id=~"197|198",attribute_value_type="raw"} > 0'';
                summary = "Disk sectors need investigation";
                description = "{{ $labels.host }} {{ $labels.device }} has {{ $value }} {{ $labels.attribute_name }} sectors. Inspect SMART details and trends, verify backups, and plan replacement if confirmed; historical reallocated-sector counts alone do not trigger this alert.";
              })
              (rule {
                alert = "SMARTReadFailed";
                # smartctl exit bits 0-2 indicate command/device/read errors, not disk health.
                expr = "smartctl_device_smartctl_exit_status % 8 > 0";
                observation = true;
                summary = "SMART observation failed";
                description = "{{ $labels.host }} {{ $labels.device }} could not be queried reliably. Inspect exporter permissions, device paths and smartctl errors. This does not establish disk failure or recovery.";
              })
            ]
            ++ lib.mapAttrsToList (
              host: count:
              rule {
                alert = "RAIDObservationMissing";
                expr = ''
                  count(node_md_disks_required{host="${host}"}) < ${toString count}
                  or absent(node_md_disks_required{host="${host}"})
                  or node_scrape_collector_success{host="${host}",collector="mdadm"} == 0
                '';
                labels = { inherit host; };
                observation = true;
                summary = "RAID observation is incomplete";
                description = "${host}: expected ${toString count} arrays. Inspect /proc/mdstat, exporter collection and the scrape path. Missing observations alone do not prove array failure or recovery.";
              }
            ) expectedArrays
            ++ map (
              host:
              rule {
                alert = "SMARTObservationMissing";
                expr = ''absent_over_time(smartctl_device_smartctl_exit_status{host="${host}"}[5m])'';
                labels = { inherit host; };
                observation = true;
                summary = "SMART observations are missing";
                description = "${host}: restore the SMART exporter and collection path. Missing results do not establish disk health.";
              }
            ) (lib.attrNames expectedArrays);
          }
        ];
      }
    ))
  ];
}
