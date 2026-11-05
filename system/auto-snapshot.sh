#!/bin/bash
# /usr/local/bin/auto-snapshot.sh — runs as root from weekly-snapshot.service (started at login).
# Same behavior as the CachyOS PC:
#   - if 7+ days have passed since the last weekly snapshot, create "weekly-YYYY-MM-DD"
#   - keep only the newest 3 weekly-* snapshots
#   - every run (snapshot or not), empty the pacman package cache
set -euo pipefail

STAMP=/var/lib/snapper-last-weekly
KEEP=3
today=$(date +%F)

days=9999
if [[ -f "$STAMP" ]]; then
    last=$(< "$STAMP")
    if last_s=$(date -d "$last" +%s 2>/dev/null); then
        days=$(( ( $(date -d "$today" +%s) - last_s ) / 86400 ))
    fi
fi

if (( days >= 7 )); then
    snapper -c root create -d "weekly-$today"
    echo "$today" > "$STAMP"
    echo "Created snapshot weekly-$today."

    mapfile -t weekly < <(snapper --csvout -c root list --columns number,description \
        | awk -F, 'NR>1 && $2 ~ /^weekly-/ {print $1}')
    count=${#weekly[@]}
    if (( count > KEEP )); then
        snapper -c root delete "${weekly[@]:0:count-KEEP}"
        echo "Deleted $((count - KEEP)) old weekly snapshot(s)."
    fi
else
    echo "Only $days days since last snapshot. Skipping."
fi

paccache -rk0
