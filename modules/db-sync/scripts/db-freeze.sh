#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: db-freeze <database> <tag>" >&2
  exit 1
fi
db="$1"
tag="$2"
src="@dbRoot@/$db"
dst="@dbRoot@/$db.frozen.$tag"
[[ -d $src ]] || {
  echo "Not found: $db" >&2
  exit 1
}
[[ ! -e $dst ]] || {
  echo "Already exists: $dst" >&2
  exit 1
}
if systemctl is-active --quiet "db-sync-$db.service" 2>/dev/null; then
  echo "Sync in progress for $db, abort" >&2
  exit 1
fi
cp --reflink=auto -a "$src" "$dst"
echo "Frozen: $dst"
