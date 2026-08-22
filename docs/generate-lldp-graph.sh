#!/usr/bin/env bash
set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  echo "$(basename "$0") requires Bash 4 or newer" >&2
  exit 1
fi

report="../graph.md"
url="https://github.com/SBEE-Lab/infra/blob/main/docs/hosts"
declare -A interfaces

{
  echo '```mermaid'
  echo '  graph TD'

  for host_file in *; do
    [[ -f $host_file ]] || continue
    while read -r neighbor; do
      [[ -z $neighbor ]] && continue
      host_interface=$(echo "$neighbor" | cut -d' ' -f1)
      link_speed=$(echo "$neighbor" | cut -d' ' -f2)
      neighbor_interface=$(echo "$neighbor" | cut -d' ' -f3 | tr -cd '[:alnum:]._-')
      neighbor_name=$(echo "$neighbor" | cut -d' ' -f4 | tr -cd '[:alnum:]._-')

      interfaces[$host_file]+=" $host_interface"
      interfaces[$neighbor_name]+=" $neighbor_interface"

      echo "      ${host_file}.${host_interface}[\"$host_interface\"]-- $link_speed ---${neighbor_name}.${neighbor_interface}[\"$neighbor_interface\"]"
    done <"$host_file"
  done

  for host in "${!interfaces[@]}"; do
    interfaces[$host]=$(xargs -n 1 <<<"${interfaces[$host]}" | sort -u | xargs)
    echo "      subgraph $host"
    for interface in ${interfaces[$host]}; do
      echo "      ${host}.${interface}[\"$interface\"]"
    done
    echo "      end"
  done

  for host in "${!interfaces[@]}"; do
    [[ -f "../$host.md" ]] || continue
    for interface in ${interfaces[$host]}; do
      echo "      click ${host}.${interface} \"$url/$host.md\" \"$host\""
    done
  done

  echo '```'
} >"$report"

# Remove inverse duplicate links.
while true; do
  duplicate=""
  while read -r link; do
    interface_1=$(awk '{print $1}' <<<"$link" | rev | cut -c 3- | rev)
    link_speed=$(awk '{print $2}' <<<"$link")
    interface_2=$(awk '{print $3}' <<<"$link" | cut -c 4-)
    candidate="$interface_2-- $link_speed ---$interface_1"
    if grep -q -F "$candidate" "$report"; then
      duplicate=$candidate
      break
    fi
  done < <(grep -E -- '-- [[:digit:]]+[GM] ---' "$report")

  [[ -n $duplicate ]] || break
  tempfile=$(mktemp -t sbee-lldp-graph.XXXXXX)
  awk -v pattern="$duplicate" 'index($0, pattern) == 0' "$report" >"$tempfile"
  mv "$tempfile" "$report"
done
