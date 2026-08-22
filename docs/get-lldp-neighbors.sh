#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${1:-} ]]; then
  echo "Usage: $(basename "$0") host" >&2
  exit 1
fi

target=$1
hostname=${target%%.*}
report="$hostname"
lldp=$(ssh "$target" -- networkctl lldp --json=short)

while IFS=$'	' read -r interface neighbor_interface neighbor_name; do
  [[ -z $interface ]] && continue
  link_speed=$(ssh "$target" -- cat "/sys/class/net/$interface/speed" </dev/null)

  if ((link_speed >= 1000)); then
    speed="$((link_speed / 1000))G"
  else
    speed="${link_speed}M"
  fi
  echo "$interface $speed $neighbor_interface $neighbor_name"
done < <(
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
for interface in data.get("Neighbors", []):
    name = interface["InterfaceName"]
    for neighbor in interface.get("Neighbors", []):
        remote_interface = (
            neighbor.get("PortDescription")
            or neighbor.get("PortID")
            or neighbor.get("ChassisID")
        )
        remote_name = neighbor.get("SystemName") or neighbor.get("ChassisID")
        print(name, remote_interface, remote_name, sep="\t")
' <<<"$lldp"
) >"$report"

echo "wrote $report" >&2
