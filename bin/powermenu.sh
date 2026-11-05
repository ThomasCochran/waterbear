#!/bin/bash
# Ctrl+Alt+P: power menu.
pkill -x rofi && exit 0
choice=$(printf '%s\n' "  lock" "  logout" "  suspend" "  reboot" "  shutdown" \
    | rofi -dmenu -i -p "power" -l 5) || exit 0
case "$choice" in
    *lock)     pidof hyprlock || hyprlock ;;
    *logout)   hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
    *suspend)  systemctl suspend ;;
    *reboot)   systemctl reboot ;;
    *shutdown) systemctl poweroff ;;
esac
