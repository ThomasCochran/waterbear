# lib/palette.sh — make a theme from a picture (like Aether) or from colors you type in.
# A theme is the same 21-color PALETTE line the built-in schemes use:
#   BG FG A B DIM C0..C15   (C0/C8 = raised background / borders, C1-C6 = red green yellow blue magenta cyan,
#                            C9-C14 = their bright versions, C7/C15 = light text)

# palette_derive MODE [BG FG A B] < "count hex" lines
#   MODE: dark | light. Colors read from stdin (from a picture) pick the background, accents and the
#   terminal colors. Any of BG FG A B passed in are used as given (your own colors).
#   Prints the PALETTE line.
palette_derive() {
    awk -v mode="$1" -v fbg="${2:-}" -v ffg="${3:-}" -v fa="${4:-}" -v fb="${5:-}" '
    function hexv(h, i) { return index("0123456789abcdef", tolower(substr(h, i, 1))) - 1 }
    function h2(h, i) { return hexv(h, i) * 16 + hexv(h, i + 1) }
    function max3(a, b, c) { return a > b ? (a > c ? a : c) : (b > c ? b : c) }
    function min3(a, b, c) { return a < b ? (a < c ? a : c) : (b < c ? b : c) }
    function clamp(x, lo, hi) { return x < lo ? lo : (x > hi ? hi : x) }
    function tohsl(hex,   r, g, b, mx, mn, d) {           # sets H S L (H in degrees)
        r = h2(hex, 1) / 255; g = h2(hex, 3) / 255; b = h2(hex, 5) / 255
        mx = max3(r, g, b); mn = min3(r, g, b); L = (mx + mn) / 2
        if (mx == mn) { H = 0; S = 0; return }
        d = mx - mn
        S = L > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        if (mx == r) H = (g - b) / d + (g < b ? 6 : 0)
        else if (mx == g) H = (b - r) / d + 2
        else H = (r - g) / d + 4
        H = H * 60
    }
    function hue2(p, q, t) {
        if (t < 0) t += 1; if (t > 1) t -= 1
        if (t < 1/6) return p + (q - p) * 6 * t
        if (t < 1/2) return q
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
        return p
    }
    function hsl(h, s, l,   q, p, r, g, b) {             # -> hex
        h = (h % 360 + 360) % 360 / 360; s = clamp(s, 0, 1); l = clamp(l, 0, 1)
        if (s == 0) { r = g = b = l }
        else {
            q = l < 0.5 ? l * (1 + s) : l + s - l * s; p = 2 * l - q
            r = hue2(p, q, h + 1/3); g = hue2(p, q, h); b = hue2(p, q, h - 1/3)
        }
        return sprintf("%02x%02x%02x", int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5))
    }
    function chan(c) { c = c / 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
    function lum(hex) { return 0.2126 * chan(h2(hex, 1)) + 0.7152 * chan(h2(hex, 3)) + 0.0722 * chan(h2(hex, 5)) }
    function contrast(x, y,   a, b) { a = lum(x); b = lum(y); return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05) }
    function mix(x, y, t) {                                 # t = share of y
        return sprintf("%02x%02x%02x", h2(x,1) * (1-t) + h2(y,1) * t, h2(x,3) * (1-t) + h2(y,3) * t, h2(x,5) * (1-t) + h2(y,5) * t)
    }
    function hdist(a, b,   d) { d = a - b; if (d < 0) d = -d; return d > 180 ? 360 - d : d }
    # push a color away from the background until it has at least the given contrast
    function readable(h, s, l, need,   c, i) {
        for (i = 0; i < 40; i++) {
            c = hsl(h, s, l)
            if (contrast(c, BGC) >= need) return c
            l += dark ? 0.02 : -0.02
        }
        return c
    }
    { if ($2 ~ /^#?[0-9a-fA-F]{6}$/) { sub(/^#/, "", $2); n++; cnt[n] = $1 + 0; hex[n] = tolower($2); total += cnt[n]
          tohsl(hex[n]); ch[n] = H; cs[n] = S; cl[n] = L } }
    END {
        dark = (mode != "light")
        # Background: the most common darkish (light mode: lightish) color, very dark (light)
        best = 0; bh = 220; bs = 0.2
        for (i = 1; i <= n; i++) {
            w = cnt[i] * (dark ? (1.2 - cl[i]) : (cl[i] + 0.2))
            if (w > best) { best = w; bh = ch[i]; bs = cs[i] }
        }
        if (fbg != "") BGC = fbg
        else BGC = dark ? hsl(bh, clamp(bs, 0, 0.35), 0.075) : hsl(bh, clamp(bs, 0, 0.25), 0.95)
        tohsl(BGC); bgh = H; bgs = S; bgl = L

        # Accents: vivid colors, weighted by how much of the picture they cover
        ia = 0; sa = -1
        for (i = 1; i <= n; i++) {
            v = cs[i] * (cnt[i] / (total ? total : 1)) ^ 0.35 * ((cl[i] > 0.15 && cl[i] < 0.9) ? 1 : 0.25)
            score[i] = v; if (v > sa) { sa = v; ia = i }
        }
        if (fa != "") { A = fa; tohsl(A); ah = H }
        else {
            if (ia && cs[ia] > 0.12) { ah = ch[ia]; as = clamp(cs[ia], 0.5, 0.95) } else { ah = (bgh + 180) % 360; as = 0.6 }
            A = readable(ah, as, dark ? 0.6 : 0.42, 3.5)
        }
        if (fb != "") B = fb
        else {
            ib = 0; sb = -1
            for (i = 1; i <= n; i++) if (i != ia && cs[i] > 0.15 && hdist(ch[i], ah) >= 40 && score[i] > sb) { sb = score[i]; ib = i }
            if (ib) { bh2 = ch[ib]; bs2 = clamp(cs[ib], 0.5, 0.95) } else { bh2 = ah + 40; bs2 = 0.65 }
            B = readable(bh2, bs2, dark ? 0.68 : 0.38, 4)
        }
        FG = (ffg != "") ? ffg : readable(bgh, 0.15, dark ? 0.86 : 0.18, 9)
        DIM = mix(FG, BGC, 0.45)
        C0 = dark ? hsl(bgh, bgs, bgl + 0.05) : hsl(bgh, bgs, bgl - 0.05)
        C8 = dark ? hsl(bgh, clamp(bgs, 0, 0.3), bgl + 0.17) : hsl(bgh, clamp(bgs, 0, 0.3), bgl - 0.2)
        C7 = mix(FG, BGC, 0.12); C15 = dark ? mix(FG, "ffffff", 0.5) : mix(FG, "000000", 0.5)

        # Terminal colors: the closest color of that hue in the picture, otherwise a clean one
        split("0 120 50 220 300 180", tgt, " ")
        for (k = 1; k <= 6; k++) {
            found = 0; fbst = 0
            for (i = 1; i <= n; i++) if (cs[i] > 0.25 && hdist(ch[i], tgt[k]) <= 30 && cnt[i] > fbst) { fbst = cnt[i]; found = i }
            hh = found ? ch[found] : tgt[k]; ss = found ? clamp(cs[found], 0.5, 0.9) : 0.62
            ANS[k] = readable(hh, ss, dark ? 0.6 : 0.4, 3)
            BR[k] = readable(hh, ss, dark ? 0.72 : 0.33, 3.5)
        }
        printf "%s %s %s %s %s %s", BGC, FG, A, B, DIM, C0
        for (k = 1; k <= 6; k++) printf " %s", ANS[k]
        printf " %s %s", C7, C8
        for (k = 1; k <= 6; k++) printf " %s", BR[k]
        printf " %s\n", C15
    }'
}

# The colors in a picture: "count hex" lines (needs ImageMagick)
picture_colors() {
    magick "$1[0]" -resize '200x200>' -colors 16 -format '%c' histogram:info:- 2> /dev/null |
        sed -nE 's/^ *([0-9]+):.*#([0-9A-Fa-f]{6}).*/\1 \2/p'
}

palette_preview() {  # palette_preview "PALETTE"
    local p; read -ra p <<< "$1"
    printf '  background · text · accent · accent 2 · dim\n  '
    swatch "${p[0]}" "${p[1]}" "${p[2]}" "${p[3]}" "${p[4]}"
    printf '  terminal colors\n  '
    swatch "${p[@]:5:8}"
    printf '  '
    swatch "${p[@]:13:8}"
    printf '\n  \e[48;2;%sm\e[38;2;%sm  Some text on the background · \e[38;2;%sm accent \e[38;2;%sm accent 2 \e[38;2;%sm dim  \e[0m\n\n' \
        "$(_m_rgb "${p[0]}")" "$(_m_rgb "${p[1]}")" "$(_m_rgb "${p[2]}")" "$(_m_rgb "${p[3]}")" "$(_m_rgb "${p[4]}")"
}

theme_write() {  # theme_write NAME "PALETTE" DESC
    mkdir -p "$WB_USER_SCHEMES"
    {
        echo "# $1 — made in Waterbear ($(date +%F))"
        echo "DESC=\"${3//\"/}\""
        echo "PALETTE=\"$2\""
    } > "$WB_USER_SCHEMES/$1"
}

theme_name_ask() {  # asks for a new theme name; prints it
    local n
    while true; do
        n=$(ui_input "Name for this theme (letters, numbers, - and _)" "${1:-}") || return 1
        n=$(tr '[:upper:] ' '[:lower:]-' <<< "$n" | tr -cd 'a-z0-9_-')
        [[ -z "$n" ]] && continue
        if [[ "$n" == custom || "$n" == old_theme || -f "$WB_HOME/schemes/$n" ]]; then
            warn "'$n' is taken by a built-in theme. Pick another name."; continue
        fi
        if [[ -f "$WB_USER_SCHEMES/$n" ]] && ! ui_confirm "You already have a theme called $n. Replace it?" n; then continue; fi
        echo "$n"; return 0
    done
}

# Shows a made palette and asks what to do. "Just try it" saves it as the temporary theme "custom".
# Returns 0 when a theme was applied, 1 when cancelled, 2 = make it again.
theme_offer() {  # theme_offer "PALETTE" DESC [SUGGESTED_NAME]
    local pal="$1" desc="$2" p name c
    while true; do
        ui_title "New theme"
        palette_preview "$pal"
        c=$(ui_pick "Use these colors?" save \
            "Save to my themes (pick a name)::save" \
            "Just try it (not saved; save it later from Theme)::try" \
            "Swap the two accent colors::swap" \
            "Make it again::again" \
            "Cancel::cancel") || return 1
        case "$c" in
            swap)  read -ra p <<< "$pal"; local t="${p[2]}"; p[2]="${p[3]}"; p[3]="$t"; pal="${p[*]}" ;;
            again) return 2 ;;
            cancel) return 1 ;;
            try)   theme_write custom "$pal" "$desc (not saved yet)"
                   SCHEME=custom; ACCENT=""; return 0 ;;
            save)  name=$(theme_name_ask "${3:-}") || continue
                   theme_write "$name" "$pal" "$desc"
                   SCHEME="$name"; ACCENT=""; return 0 ;;
        esac
    done
}

pick_picture() {  # prints the path of a picture you choose
    local dirs=() d sel
    for d in "$HOME/Pictures" "$HOME/Downloads" "$HOME/Wallpapers" "$HOME/Pictures/Wallpapers" "$WB_CONF/wallpapers"; do [[ -d "$d" ]] && dirs+=("$d"); done
    if command -v fzf > /dev/null && (( ${#dirs[@]} )); then
        sel=$( { find "${dirs[@]}" -maxdepth 3 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2> /dev/null | sort -u
                 echo "[ type a path ]"; } |
            fzf --layout=reverse --height=100% --prompt "picture ❯ " --bind 'left:abort' \
                --header "pick a picture · enter = use it · esc = back" "$(fzf_theme)") || return 1
    else
        sel="[ type a path ]"
    fi
    if [[ "$sel" == "[ type a path ]" ]]; then
        sel=$(ui_input "Path to the picture (png, jpg, webp)" "$HOME/") || return 1
        sel="${sel/#\~/$HOME}"
    fi
    [[ -f "$sel" ]] || { warn "No picture at: $sel"; ui_pause; return 1; }
    echo "$sel"
}

picture_keep() {  # copies a picture into ~/.config/waterbear/wallpapers; prints the new path
    local src="$1" ext dest
    ext="${src##*.}"; ext=$(tr '[:upper:]' '[:lower:]' <<< "$ext")
    mkdir -p "$WB_CONF/wallpapers"
    dest="$WB_CONF/wallpapers/$(basename "${src%.*}" | tr -c 'A-Za-z0-9_-' '-' | sed 's/-*$//').$ext"
    [[ "$(readlink -f "$src")" == "$(readlink -f "$dest" 2> /dev/null)" ]] || cp "$src" "$dest"
    echo "$dest"
}

# Look & feel → Theme → From a picture
theme_from_picture() {
    local img mode=dark rc pal name
    img=$(pick_picture) || return 1
    if ! command -v magick > /dev/null; then
        info "Reading colors from a picture needs ImageMagick."
        ui_confirm "Install ImageMagick now?" y || return 1
        need_sudo; pac imagemagick || return 1
    fi
    [[ "$DARK_MODE" == yes ]] || mode=light
    local colors; colors=$(picture_colors "$img")
    [[ -n "$colors" ]] || { warn "Couldn't read colors from $img."; ui_pause; return 1; }
    name=$(basename "${img%.*}" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9_-')
    while true; do
        pal=$(palette_derive "$mode" <<< "$colors")
        rc=0; theme_offer "$pal" "made from $(basename "$img")" "$name" || rc=$?
        case $rc in
            0) break ;;
            2) [[ "$mode" == dark ]] && mode=light || mode=dark   # "make it again" flips light/dark
               info "Making a $mode version..." ;;
            *) return 1 ;;
        esac
    done
    # The background is its own setting: only change it if you want
    if ui_confirm "Also use this picture as your background?" y; then
        WALL_IMAGE=$(picture_keep "$img"); WALLPAPER=picture
    fi
    return 0
}

ask_hex() {  # ask_hex QUESTION DEFAULT -> prints rrggbb
    local v
    while true; do
        v=$(ui_input "$1  (hex, like #1e1e2e)" "#$2") || return 1
        v="${v#\#}"; v=$(tr '[:upper:]' '[:lower:]' <<< "$v")
        [[ "$v" =~ ^[0-9a-f]{6}$ ]] && { echo "$v"; return 0; }
        warn "'$v' isn't a 6-digit hex color."
    done
}

# Look & feel → Theme → Type your own colors (starts from the current theme's colors)
theme_from_colors() {  # [NAME] — when changing one of your themes
    local bg fg a b mode=dark pal rc
    ui_title "Your own colors"
    info "Type four colors; Waterbear works out the rest (terminal colors, borders, dim text)."; echo
    bg=$(ask_hex "Background" "$P_BG") || return 1
    fg=$(ask_hex "Text" "$P_FG") || return 1
    a=$(ask_hex "Accent (borders, highlights)" "$P_A") || return 1
    b=$(ask_hex "Second accent (clock, cursor, prompt)" "$P_B") || return 1
    local L; L=$(( 16#${bg:0:2} * 299 + 16#${bg:2:2} * 587 + 16#${bg:4:2} * 114 ))
    (( L >= 128000 )) && mode=light
    pal=$(palette_derive "$mode" "$bg" "$fg" "$a" "$b" < /dev/null)
    if ui_confirm "Change any of the 16 terminal colors by hand too?" n; then
        local p i names=(black red green yellow blue magenta cyan white "bright black" "bright red" "bright green" "bright yellow" "bright blue" "bright magenta" "bright cyan" "bright white")
        read -ra p <<< "$pal"
        for i in $(seq 0 15); do p[$((i + 5))]=$(ask_hex "Terminal color $i (${names[$i]})" "${p[$((i + 5))]}") || return 1; done
        pal="${p[*]}"
    fi
    rc=0; theme_offer "$pal" "your own colors" "${1:-}" || rc=$?
    [[ $rc -eq 0 ]]
}

# Look & feel → Theme → Manage your themes
themes_manage() {
    while true; do
        ui_title "Your themes"
        local opts=() t
        for t in $(scheme_user); do opts+=("$(printf '%-14s' "$t")  $(scheme_desc "$t")::$t"); done
        [[ ${#opts[@]} -eq 0 ]] && { info "You haven't made any themes yet."; ui_pause; return 0; }
        t=$(ui_pick "Pick one of your themes" "$SCHEME" "${opts[@]}") || return 0
        local act
        act=$(ui_pick "Theme: $t" rename \
            "Rename (or save under a new name)::rename" \
            "Change its colors::edit" \
            "Delete it::delete") || continue
        case "$act" in
            rename) local n; n=$(theme_name_ask "$t") || continue
                    [[ "$n" == "$t" ]] && continue
                    mv "$WB_USER_SCHEMES/$t" "$WB_USER_SCHEMES/$n"
                    sed -i 's/ (not saved yet)"$/"/' "$WB_USER_SCHEMES/$n"
                    [[ "$SCHEME" == "$t" ]] && { SCHEME="$n"; state_save; }
                    ok "Saved as $n." ; ui_pause ;;
            edit)   local old="$SCHEME"; SCHEME="$t"; scheme_load "$t"
                    if theme_from_colors "$t"; then state_save; apply_all; ui_pause; else SCHEME="$old"; fi ;;
            delete) ui_confirm "Delete the theme $t?" n || continue
                    rm -f "$WB_USER_SCHEMES/$t"
                    if [[ "$SCHEME" == "$t" ]]; then SCHEME=abyss; ACCENT=""; state_save; apply_all; fi
                    ok "Deleted $t."; ui_pause ;;
        esac
    done
}
