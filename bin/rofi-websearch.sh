#!/bin/bash
# Super+S: type a query in rofi, open a Google search in the browser.
pkill -x rofi && exit 0
query=$(rofi -dmenu -p "google" -l 0) || exit 0
[[ -z "$query" ]] && exit 0
encoded=$(jq -rn --arg q "$query" '$q | @uri')
xdg-open "https://www.google.com/search?q=${encoded}" > /dev/null 2>&1 &
