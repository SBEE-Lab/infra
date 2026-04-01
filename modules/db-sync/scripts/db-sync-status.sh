#!/usr/bin/env bash
set -euo pipefail
systemctl list-timers 'db-sync-*' --all --no-pager
echo ""
printf "%-40s %-10s %-10s %s\n" "SERVICE" "STATE" "RESULT" "LAST RUN"
printf "%-40s %-10s %-10s %s\n" "-------" "-----" "------" "--------"
for svc in $(systemctl list-units 'db-sync-*.service' --plain --no-legend --all | awk '{print $1}' | grep -v notify); do
  result=$(systemctl show "$svc" -p Result --value)
  active=$(systemctl show "$svc" -p ActiveState --value)
  started=$(systemctl show "$svc" -p ExecMainStartTimestamp --value)
  if [[ -z $started ]]; then
    started="never"
    result="-"
  fi
  printf "%-40s %-10s %-10s %s\n" "$svc" "$active" "$result" "$started"
done
echo ""
echo "Disk usage:"
du -sh "@dbRoot@"/*/ 2>/dev/null | sort -k2 || echo "  (no databases found)"
