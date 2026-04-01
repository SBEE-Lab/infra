#!/usr/bin/env bash
set -euo pipefail
systemctl list-timers 'db-sync-*' --all --no-pager
echo ""
for svc in $(systemctl list-units 'db-sync-*.service' --plain --no-legend --all | awk '{print $1}' | grep -v notify); do
  result=$(systemctl show "$svc" -p Result --value)
  active=$(systemctl show "$svc" -p ActiveState --value)
  printf "%-40s %s (%s)\n" "$svc" "$active" "$result"
done
