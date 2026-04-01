#!/usr/bin/env bash
set -euo pipefail
for timer in $(systemctl list-units 'db-sync-*.timer' --plain --no-legend | awk '{print $1}'); do
  svc="${timer%.timer}.service"
  echo "Starting $svc ..."
  systemctl start --no-block "$svc"
done
echo "All sync services triggered (running in background)"
