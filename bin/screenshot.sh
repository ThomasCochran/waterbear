#!/bin/bash
# Screenshots: full | area | window | edit | delay <seconds>
# Saves to ~/Pictures/Screenshots and copies the image to the clipboard.
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%F_%H-%M-%S).png"

case "$1" in
    full)   grim "$file" ;;
    area)   geom=$(slurp) || exit 0; grim -g "$geom" "$file" ;;
    window) geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
            grim -g "$geom" "$file" ;;
    edit)   geom=$(slurp) || exit 0; grim -g "$geom" - | swappy -f -; exit 0 ;;
    delay)  secs="${2:-5}"
            notify-send -t 1500 "Screenshot in ${secs}s"
            sleep "$secs"; grim "$file" ;;
    *)      echo "usage: $0 full|area|window|edit|delay N" >&2; exit 1 ;;
esac

[[ -f "$file" ]] || exit 1
wl-copy < "$file"
notify-send -i "$file" "Screenshot saved" "$file"
