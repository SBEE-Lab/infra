#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 2 ]]; then
  echo "Usage: db-thaw <database> <tag>" >&2
  exit 1
fi
db="$1"
tag="$2"
target="@dbRoot@/$db.frozen.$tag"
[[ -d $target ]] || {
  echo "Not found: $target" >&2
  exit 1
}
rm -rf "$target"
echo "Thawed: $db.frozen.$tag"
