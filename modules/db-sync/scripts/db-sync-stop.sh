#!/usr/bin/env bash
set -euo pipefail
if [[ $# -eq 0 ]]; then
  # Stop all running sync services
  for svc in $(systemctl list-units 'db-sync-*.service' --plain --no-legend --state=activating,running | awk '{print $1}'); do
    echo "Stopping $svc ..."
    systemctl stop "$svc"
  done
  echo "All sync services stopped"
else
  # Stop specific database(s)
  for db in "$@"; do
    svc="db-sync-${db}.service"
    echo "Stopping $svc ..."
    systemctl stop "$svc"
  done
fi
