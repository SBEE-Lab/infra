#!/usr/bin/env bash
set -euo pipefail

user=${1:-}

if [[ -z $user ]]; then
  echo "Missing username"
  echo "Usage: $(basename "$0") username"
  exit 1
fi

# GitHub directory pages change independently of this script; use the stable API.
tempfile=$(mktemp -t sbee-hosts.XXXXXX)
trap 'rm -f "$tempfile"' EXIT

cat <<EOF
# File generated automatically by $(basename "$0")

####################################################
####   SBEE servers
####################################################

Host eta
     HostName jump.sjanglab.org
     User $user
     Port 10022

EOF

curl -fsSL \
  -H 'Accept: application/vnd.github+json' \
  -H 'X-GitHub-Api-Version: 2022-11-28' \
  'https://api.github.com/repos/SBEE-Lab/infra/contents/hosts?ref=main' \
  >"$tempfile"
machines=$(grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+\.nix"' "$tempfile" |
  sed -E 's/.*"([^"]+)\.nix"/\1/' |
  sort -u)

while read -r machine; do
  if [[ -z $machine || $machine == "eta" ]]; then
    continue
  fi

  cat <<EOF
Host $machine
     HostName $machine.sjanglab.org
     User $user
     Port 10022
     ForwardAgent yes
     ProxyJump eta

EOF
done <<<"$machines"
