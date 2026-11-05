#!/bin/bash
# Super+I: quick status popup, since there's no bar.
bat=""
for b in /sys/class/power_supply/BAT*; do
    [[ -d "$b" ]] && bat="$(cat "$b/capacity")% ($(cat "$b/status"))"
done
wifi=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%d%%", $2*100} /MUTED/{printf " (muted)"}')
notify-send -t 4000 "$(date '+%H:%M  ·  %a %b %-d')" \
    "battery  ${bat:-n/a}\nwifi     ${wifi:-disconnected}\nvolume   ${vol:-n/a}"
