#!/bin/bash
# Super+S: type a query in rofi, open a web search in the browser.
# Google, or DuckDuckGo once you add it (Waterbear → Install → Browsers → DuckDuckGo).
pkill -x rofi && exit 0
SEARCH=google
# shellcheck disable=SC1090
[[ -f "$HOME/.config/waterbear/state.conf" ]] && . "$HOME/.config/waterbear/state.conf"
case "$SEARCH" in
    duckduckgo) name=duckduckgo; url="https://duckduckgo.com/?q=" ;;
    *)          name=google;     url="https://www.google.com/search?q=" ;;
esac
query=$(rofi -dmenu -p "$name" -l 0) || exit 0
[[ -z "$query" ]] && exit 0
encoded=$(jq -rn --arg q "$query" '$q | @uri')
xdg-open "${url}${encoded}" > /dev/null 2>&1 &
