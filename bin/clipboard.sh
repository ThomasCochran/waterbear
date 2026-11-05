#!/bin/bash
# Super+Alt+V: pick an entry from clipboard history and copy it again.
pkill -x rofi && exit 0
choice=$(cliphist list | rofi -dmenu -p "clipboard" -display-columns 2) || exit 0
printf '%s' "$choice" | cliphist decode | wl-copy
