#!/bin/bash
# Super+Shift+K: fuzzy-search the keybind cheat sheet.
pkill -x rofi && exit 0
grep -E '^\| ' ~/.config/hypr/KEYBINDS.md \
    | grep -v -E '^\| *(Shortcut|-)' \
    | sed -E 's/^\| *//; s/ *\| */  →  /; s/ *\| *$//' \
    | rofi -dmenu -i -p "keybinds" > /dev/null
