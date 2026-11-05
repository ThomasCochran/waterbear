#!/bin/bash
# Dropdown terminal: start it if it isn't running, then show/hide its special workspace.
if ! hyprctl clients -j | jq -e '.[] | select(.class == "dropterm")' > /dev/null; then
    kitty --class dropterm &
fi
hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropterm")'
