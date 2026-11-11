# lib/core.sh — shared pieces: paths, saved settings, color schemes, templating, menus.
# Sourced by the `waterbear` command.

WB_HOME="${WATERBEAR_HOME:-$HOME/.local/share/waterbear}"
WB_CONF="$HOME/.config/waterbear"
WB_STATE="$WB_CONF/state.conf"
WB_REPO_URL="https://github.com/ThomasCochran/waterbear.git"
WB_RAW_URL="https://raw.githubusercontent.com/ThomasCochran/waterbear/main"   # for the login version check
WB_BIN="$HOME/.local/bin"
WB_VERSION="$(cat "$WB_HOME/VERSION" 2> /dev/null || echo unknown)"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
c_cyan=$'\033[1;36m'; c_yel=$'\033[1;33m'; c_red=$'\033[1;31m'; c_grn=$'\033[1;32m'
c_dim=$'\033[2m'; c_off=$'\033[0m'
step() { printf '\n%s==>%s %s\n' "$c_cyan" "$c_off" "$1"; }
ok()   { printf '%s ok%s %s\n' "$c_grn" "$c_off" "$1"; }
info() { printf '    %s\n' "$1"; }
warn() { printf '%s !!%s %s\n' "$c_yel" "$c_off" "$1"; }
die()  { printf '%s xx%s %s\n' "$c_red" "$c_off" "$1" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Saved settings (~/.config/waterbear/state.conf)
# ---------------------------------------------------------------------------
STATE_KEYS=(DESKTOP MENU_KEY DARK_MODE SCHEME ACCENT WALLPAPER WALL_IMAGE LIVE_ON_BATTERY LOCK_BG BAR KEYBINDS PROMPT USER_SHELL SAVER SAVER_ON_BATTERY
            IDLE_PRESET IDLE_SAVER IDLE_LOCK IDLE_OFF IDLE_SUSPEND LOGIN SNAPPER SNAPPER_WEEKLY FIREWALL FW_PORTS YAY APPS MONITORS MON_WS AUTO_UPDATE)

state_defaults() {
    DESKTOP=""      # yes once the Waterbear desktop is installed (Desktop → Install); until then nothing in ~/.config is touched
    MENU_KEY=yes    # Super+Alt+Space opens this menu
    DARK_MODE=yes   # dark GTK / Qt / Firefox (off = light)
    WALL_IMAGE=""   # your own picture, for WALLPAPER=picture
    SCHEME=abyss; ACCENT=""; WALLPAPER=solid; LIVE_ON_BATTERY=no; LOCK_BG=solid; BAR=dashboard; KEYBINDS=waterbear; PROMPT=hacker; USER_SHELL=bash
    SAVER=cmatrix; SAVER_ON_BATTERY=no
    IDLE_PRESET=normal; IDLE_SAVER=4; IDLE_LOCK=5; IDLE_OFF=7; IDLE_SUSPEND=20
    LOGIN=text; SNAPPER=yes; SNAPPER_WEEKLY=yes
    FIREWALL=yes; FW_PORTS="ssh"; YAY=no; APPS=""
    AUTO_UPDATE=ask   # off | ask (notify at login when GitHub has a newer version) | auto (install it at login)
    MONITORS=""; MON_WS=""   # empty = Hyprland places monitors and workspaces itself
}

state_load() {
    state_defaults
    # shellcheck disable=SC1090
    [[ -f "$WB_STATE" ]] && . "$WB_STATE"
    [[ "$SAVER" == random ]] && SAVER=cmatrix   # "random" was removed
    [[ "$KEYBINDS" =~ ^(waterbear|omarchy|default)$ ]] || KEYBINDS=waterbear
    if [[ -z "$DESKTOP" ]]; then   # installs from before this setting existed: the desktop is there if its configs are
        if grep -qs 'Waterbear' "$HOME/.config/hypr/binds.lua"; then DESKTOP=yes; else DESKTOP=no; fi
    fi
    scheme_file "$SCHEME" > /dev/null || SCHEME=abyss   # a deleted custom theme
    return 0
}

state_save() {
    mkdir -p "$WB_CONF"
    {
        echo "# Waterbear settings — change them with the \`waterbear\` menu (or edit, then run: waterbear apply)"
        local k
        for k in "${STATE_KEYS[@]}"; do printf '%s="%s"\n' "$k" "${!k}"; done
    } > "$WB_STATE"
}

has_app() { [[ " $APPS " == *" $1 "* ]]; }
add_app() { has_app "$1" || APPS="${APPS:+$APPS }$1"; }
del_app() { APPS=" $APPS "; APPS="${APPS// $1 / }"; APPS="${APPS# }"; APPS="${APPS% }"; }

# ---------------------------------------------------------------------------
# Color schemes
# ---------------------------------------------------------------------------
# Built-in schemes live in $WB_HOME/schemes; yours (made from a picture or your own colors) in
# ~/.config/waterbear/schemes. "old_theme" is your setup from before Waterbear (see lib/apply.sh).
WB_USER_SCHEMES="$WB_CONF/schemes"
OLD_THEME_DIR="$WB_CONF/old-theme"

scheme_file() {  # prints the file for scheme $1 (yours first, then built-in); fails if there's none
    [[ -n "$1" && "$1" != */* ]] || return 1
    if [[ "$1" == old_theme ]]; then [[ -d "$OLD_THEME_DIR" ]] && { echo "$WB_HOME/schemes/abyss"; return 0; }; return 1; fi
    local f
    for f in "$WB_USER_SCHEMES/$1" "$WB_HOME/schemes/$1"; do [[ -f "$f" ]] && { echo "$f"; return 0; }; done
    return 1
}
scheme_builtin() { local f; for f in "$WB_HOME"/schemes/*; do basename "$f"; done; }
scheme_user()    { local f; for f in "$WB_USER_SCHEMES"/*; do [[ -f "$f" ]] && basename "$f"; done; return 0; }
scheme_list()    { scheme_user; scheme_builtin; [[ -d "$OLD_THEME_DIR" ]] && echo old_theme; return 0; }
is_user_scheme() { [[ -f "$WB_USER_SCHEMES/$1" ]]; }

scheme_desc() {
    [[ "$1" == old_theme ]] && { echo "your setup from before Waterbear"; return; }
    ( DESC=""; . "$(scheme_file "$1")"; echo "$DESC" )
}

# Accent choices for schemes that offer them (e.g. Noir): prints "name:hex" lines, or nothing
scheme_accents() { [[ "$1" == old_theme ]] && return 0; ( ACCENTS=""; . "$(scheme_file "$1")"; tr ' ' '\n' <<< "$ACCENTS" | grep . ) || true; }
scheme_accent_default() { ( ACCENT_DEFAULT=""; . "$(scheme_file "$1")"; echo "$ACCENT_DEFAULT" ); }

# Loads the palette for $1 into P_BG P_FG P_A P_B P_DIM P_C0..P_C15
scheme_load() {
    local file; file=$(scheme_file "$1") || die "Unknown scheme '$1'. Options: $(scheme_list | tr '\n' ' ')"
    local PALETTE DESC ACCENTS="" ACCENT_DEFAULT="" ACCENT_SLOTS="" p
    # shellcheck disable=SC1090
    . "$file"
    read -ra p <<< "$PALETTE"
    P_BG=${p[0]}; P_FG=${p[1]}; P_A=${p[2]}; P_B=${p[3]}; P_DIM=${p[4]}
    local i; for i in $(seq 0 15); do printf -v "P_C$i" '%s' "${p[$((i + 5))]}"; done
    P_NAME="$1"; P_RAIN="$P_A"
    dark_vars
    # Schemes with a pickable accent: the chosen color becomes accent 2 (borders, cursor, clock, prompt)
    if [[ -n "$ACCENTS" ]]; then
        local want="${ACCENT:-$ACCENT_DEFAULT}" pair hex=""
        for pair in $ACCENTS; do [[ "${pair%%:*}" == "$want" ]] && hex="${pair#*:}"; done
        [[ -z "$hex" ]] && { want="$ACCENT_DEFAULT"; for pair in $ACCENTS; do [[ "${pair%%:*}" == "$want" ]] && hex="${pair#*:}"; done; }
        if [[ -n "$hex" ]]; then
            P_B="$hex"; P_RAIN="$hex"
            # Terminal colors that follow the accent too (ACCENT_SLOTS="C1:0 C9:25" = slot:% lighter),
            # so a one-accent scheme like Noir doesn't keep its default accent in the terminal
            local slot; for slot in $ACCENT_SLOTS; do
                printf -v "P_${slot%%:*}" '%s' "$(hex_lighten "$hex" "${slot#*:}")"
            done
        fi
        P_NAME="$1 ($want)"
    fi
}

# Settings that follow dark mode (used as @@GTK_THEME@@ etc. in templates)
dark_vars() {
    if [[ "${DARK_MODE:-yes}" == yes ]]; then
        T_GTK=Adwaita-dark; T_PREFER=1; T_CS=prefer-dark; T_PAPIRUS=Papirus-Dark; T_FF=0
    else
        T_GTK=Adwaita; T_PREFER=0; T_CS=default; T_PAPIRUS=Papirus; T_FF=1
    fi
}

# hex_darken RRGGBB PCT — mix the color PCT% of the way toward black
hex_darken() {
    local h="$1" pct="$2" out="" i c
    for i in 0 2 4; do
        c=$((16#${h:$i:2})); c=$(( c * (100 - pct) / 100 ))
        out+=$(printf '%02x' "$c")
    done
    echo "$out"
}

# hex_lighten RRGGBB PCT — mix the color PCT% of the way toward white
hex_lighten() {
    local h="$1" pct="$2" out="" i c
    for i in 0 2 4; do
        c=$((16#${h:$i:2})); c=$(( c + (255 - c) * pct / 100 ))
        out+=$(printf '%02x' "$c")
    done
    echo "$out"
}

# render SRC DEST [MODE] — fill @@...@@ placeholders with the loaded palette
render() {
    local src="$WB_HOME/templates/$1" dest="$2" mode="${3:-644}"
    [[ -f "$src" ]] || die "Missing template: $1"
    local args=(-e "s/@@BG@@/$P_BG/g" -e "s/@@FG@@/$P_FG/g" -e "s/@@A@@/$P_A/g" -e "s/@@B@@/$P_B/g"
                -e "s/@@DIM@@/$P_DIM/g" -e "s/@@RAIN@@/$P_RAIN/g" -e "s/@@SCHEME_NAME@@/$P_NAME/g"
                -e "s/@@GTK_THEME@@/$T_GTK/g" -e "s/@@PREFER_DARK@@/$T_PREFER/g" -e "s/@@COLOR_SCHEME@@/$T_CS/g"
                -e "s/@@ICON_THEME@@/${T_ICONS:-Adwaita}/g" -e "s/@@A_DARK@@/$(hex_darken "$P_A" 25)/g" -e "s/@@B_DARK@@/$(hex_darken "$P_B" 25)/g")
    local i v; for i in $(seq 15 -1 0); do v="P_C$i"; args+=(-e "s/@@C$i@@/${!v}/g"); done
    mkdir -p "$(dirname "$dest")"
    sed "${args[@]}" "$src" > "$dest"
    chmod "$mode" "$dest"
}

# ---------------------------------------------------------------------------
# Menus (gum). INTERACTIVE=false makes every question take its default.
# ---------------------------------------------------------------------------
INTERACTIVE=true

ui_colors() {  # color gum with the current scheme
    export GUM_CHOOSE_CURSOR_FOREGROUND="#$P_B" GUM_CHOOSE_HEADER_FOREGROUND="#$P_A"
    export GUM_CHOOSE_SELECTED_FOREGROUND="#$P_A" GUM_CHOOSE_ITEM_FOREGROUND="#$P_FG"
    export GUM_CONFIRM_PROMPT_FOREGROUND="#$P_FG" GUM_CONFIRM_SELECTED_BACKGROUND="#$P_A"
    export GUM_CONFIRM_SELECTED_FOREGROUND="#$P_BG" GUM_CONFIRM_UNSELECTED_FOREGROUND="#$P_DIM"
    export GUM_INPUT_HEADER_FOREGROUND="#$P_A" GUM_INPUT_PROMPT_FOREGROUND="#$P_B"
    export GUM_INPUT_CURSOR_FOREGROUND="#$P_B"
    export GUM_CHOOSE_CURSOR="❯ " GUM_CHOOSE_SELECTED_PREFIX="[x] " GUM_CHOOSE_UNSELECTED_PREFIX="[ ] "
    export GUM_CHOOSE_CURSOR_PREFIX="[ ] "
}

ui_title() {  # big header box
    $INTERACTIVE || return 0
    clear
    gum style --border rounded --border-foreground "#$P_A" --foreground "#$P_B" \
        --padding "0 2" --margin "0 1" "Waterbear  ·  $1" "version $WB_VERSION"
}

# ui_pick HEADER DEFAULT "label::value"...  -> prints chosen value. A "-- Heading" item is a section title.
ui_pick() {
    local header="$1" def="$2"; shift 2
    if ! $INTERACTIVE; then echo "$def"; return 0; fi
    local _M_LABELS=() _M_VALUES=() _M_RESULT="" o cur=0 i=0
    for o in "$@"; do
        if [[ "$o" == --* ]]; then _M_LABELS+=("$o"); _M_VALUES+=("")
        else _M_LABELS+=("${o%%::*}"); _M_VALUES+=("${o##*::}"); [[ "${o##*::}" == "$def" ]] && cur=$i; fi
        ((i++)) || true
    done
    _menu pick "$header" "$cur" || return 1
    echo "${_M_VALUES[$_M_RESULT]}"
}

# ui_checks HEADER "on values" "label::value"...  -> prints chosen values, space separated
ui_checks() {
    local header="$1" on="$2"; shift 2
    if ! $INTERACTIVE; then echo "$on"; return 0; fi
    local _M_LABELS=() _M_VALUES=() _M_ON=() _M_RESULT="" o i=0
    for o in "$@"; do
        if [[ "$o" == --* ]]; then _M_LABELS+=("$o"); _M_VALUES+=("")
        else
            _M_LABELS+=("${o%%::*}"); _M_VALUES+=("${o##*::}")
            [[ " $on " == *" ${o##*::} "* ]] && _M_ON[$i]=1
        fi
        ((i++)) || true
    done
    _menu checks "$header" 0 || return 1
    local out=() idx
    for idx in $_M_RESULT; do out+=("${_M_VALUES[$idx]}"); done
    echo "${out[*]}"
}

ui_confirm() {  # ui_confirm QUESTION DEFAULT(y/n)
    if ! $INTERACTIVE; then [[ "$2" == y ]]; return; fi
    if [[ "$2" == y ]]; then gum confirm "$1"; else gum confirm --default=false "$1"; fi
}

ui_input() {  # ui_input HEADER DEFAULT [PLACEHOLDER]
    if ! $INTERACTIVE; then echo "$2"; return 0; fi
    gum input --header "$1  (enter = ok, esc = back)" --value "$2" ${3:+--placeholder "$3"}
}

ui_yesno() {  # ui_yesno QUESTION DEFAULT(yes/no) -> prints yes/no; fails on esc (unlike gum confirm)
    ui_pick "$1" "$2" "Yes::yes" "No::no"
}

# ui_steps STEP... — run question steps in order, with esc going back one step.
# Each step is a function that sets its variables and returns:
#   0 = answered (go forward)   1 = esc pressed (go back)   2 = doesn't apply (skip, keep direction)
# Esc on the first step leaves and undoes every answer from these steps (returns 1).
ui_steps() {
    local steps=("$@") i=0 dir=1 rc saved
    saved=$(declare -p "${STATE_KEYS[@]}" 2> /dev/null) || true
    while (( i >= 0 && i < ${#steps[@]} )); do
        rc=0; "${steps[$i]}" || rc=$?
        case $rc in
            0) dir=1 ;;
            2) ;;
            *) dir=-1 ;;
        esac
        i=$(( i + dir ))
    done
    if (( i < 0 )); then
        eval "${saved//declare -/declare -g -}"
        scheme_load "$SCHEME"; ui_colors
        return 1
    fi
    return 0
}

ui_pause() { $INTERACTIVE && { echo; read -rsn1 -p "  press any key to continue"; echo; }; return 0; }

need_sudo() { sudo -v || die "This needs your password (sudo)."; }

on_arch() { [[ -f /etc/arch-release ]]; }

pkg_installed() { pacman -T "$1" > /dev/null 2>&1; }   # also true when another package provides it (localsend-bin → localsend)

pac() {  # pac PKG... — install official packages, skipping installed ones
    [[ $# -eq 0 ]] && return 0
    sudo pacman -S --needed --noconfirm "$@"
}

# swatch HEX... — a row of colored blocks (truecolor)
swatch() {
    local h; for h in "$@"; do printf '\e[48;2;%sm      \e[0m' "$(_m_rgb "$h")"; done; echo
}

desktop_needed() {  # says so and fails when the Waterbear desktop isn't installed yet
    [[ "$DESKTOP" == yes ]] && return 0
    info "Saved. It takes effect once you install the Waterbear desktop (menu → Desktop → Install)."
    return 1
}
