#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${1:-} ]]; then
  echo "Usage: $(basename "$0") host" >&2
  exit 1
fi

target=$1
hostname=${target%%.*}
report="$hostname.md"
lstopo="$hostname.lstopo.svg"
printf '# %s

```
' "$hostname" >"$report"
ssh "$target" -- "nix-shell -p 'inxi.override { withRecommends = true; }' --run 'sudo inxi -F -a -i --slots -xxx -c0 -z -m'" >>"$report"
tempfile=$(mktemp -t sbee-host-info.XXXXXX)
sed -E 's/(uuid: )[^ ]+/\1<filter>/g' "$report" >"$tempfile"
mv "$tempfile" "$report"
ssh "$target" -- "nix-shell -p hwloc -p dmidecode --run 'sudo lstopo /tmp/$hostname.lstopo.svg'"
scp "$target:/tmp/$hostname.lstopo.svg" "$lstopo"
ssh "$target" -- "sudo rm /tmp/$hostname.lstopo.svg"
printf '```

![hardware topology](%s)
' "$lstopo" >>"$report"
echo "wrote $report" >&2
