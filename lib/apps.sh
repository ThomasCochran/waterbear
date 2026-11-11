# lib/apps.sh — the app catalog, installed-app detection, package search, web apps.
# Each catalog entry: id|section|label|packages|flags
#   packages: "name" or "name/aur-name" (the repo package when the repos have it, otherwise that AUR package)
#   flags: aur = usually from the AUR (installs yay when needed) · hook = runs app_hook_<id> after installing
#          none = no packages (Waterbear-only extras) · webapp = a web app Waterbear makes (installed = its launcher exists)
APP_SECTIONS=(Browsers Editors "Dev tools" Terminal "Media & creative" "Office & notes" Sharing Gaming Extras)
APP_CATALOG=(
 "firefox|Browsers|Firefox|firefox|"
 "chromium|Browsers|Chromium (also runs web apps in their own window)|chromium|"
 "brave|Browsers|Brave|brave-bin|aur"
 "zen|Browsers|Zen Browser|zen-browser-bin|aur"
 "tor|Browsers|Tor Browser (private browsing over Tor · downloads and checks Tor Browser on first start)|torbrowser-launcher|"
 "duckduckgo|Browsers|DuckDuckGo (no Linux app exists: a DuckDuckGo window + Super+S searches DuckDuckGo)||none webapp hook"
 "nvim|Editors|Neovim + LazyVim (Vim as an IDE)|neovim git ripgrep fd fzf lazygit tree-sitter-cli gcc|hook"
 "vscode|Editors|VS Code (open-source build)|code|"
 "zed|Editors|Zed|zed|"
 "helix|Editors|Helix|helix|"
 "python|Dev tools|Python + pipx (latest)|python python-pipx|"
 "node|Dev tools|Node.js + npm (latest)|nodejs npm|"
 "rust|Dev tools|Rust (rustup)|rustup|hook"
 "go|Dev tools|Go|go|"
 "docker|Dev tools|Docker + Compose|docker docker-compose|hook"
 "lazygit|Dev tools|lazygit (Git in the terminal)|lazygit|"
 "lazydocker|Dev tools|lazydocker (Docker in the terminal)|lazydocker|"
 "ghcli|Dev tools|GitHub CLI (gh)|github-cli|"
 "btop|Terminal|btop (system monitor)|btop|"
 "htop|Terminal|htop (classic monitor)|htop|"
 "powertools|Terminal|Power tools (fzf · ripgrep · bat · eza · zoxide)|fzf ripgrep bat eza zoxide fd|"
 "yazi|Terminal|yazi (file manager in the terminal)|yazi|"
 "tmux|Terminal|tmux (split terminals)|tmux|"
 "ddgr|Terminal|ddgr (web search in the terminal)|ddgr|"
 "discord|Media & creative|Discord|discord|"
 "signal|Media & creative|Signal|signal-desktop|"
 "spotify|Media & creative|Spotify|spotify-launcher|"
 "mpv|Media & creative|mpv (video player)|mpv|"
 "gimp|Media & creative|GIMP (image editor)|gimp|"
 "obs|Media & creative|OBS Studio (screen recording)|obs-studio|"
 "libreoffice|Office & notes|LibreOffice|libreoffice-fresh|"
 "obsidian|Office & notes|Obsidian (notes)|obsidian|"
 "localsend|Sharing|LocalSend (send files between your phone and computer)|localsend/localsend-bin|hook"
 "kdeconnect|Sharing|KDE Connect (phone integration · open its ports in System → Firewall)|kdeconnect|"
 "steam|Gaming|Steam + GPU drivers + Proton-GE + GameMode + MangoHud||none hook"
 "cmatrix|Extras|cmatrix (Matrix rain)|cmatrix|"
 "cava|Extras|cava (music visualizer)|cava|"
 "clock|Extras|Terminal clock (type: clock)||none"
)

app_field() {  # app_field ID N  (1=id 2=section 3=label 4=packages 5=flags)
    local e; for e in "${APP_CATALOG[@]}"; do
        [[ "${e%%|*}" == "$1" ]] && { echo "$e" | cut -d'|' -f"$2"; return 0; }
    done
}

# ---------------------------------------------------------------------------
# What's installed already (so you're not asked to install what you have)
# ---------------------------------------------------------------------------
declare -A APP_INSTALLED=()
_app_main() {  # _app_main ID PACKAGES — the package(s) that show an app is installed, "/"-separated alternatives as words
    [[ "$1" == steam ]] && { echo steam; return; }
    local m="${2%% *}"; echo "${m//\// }"
}
apps_detect() {
    APP_INSTALLED=()
    local e id pk main names=() missing n
    for e in "${APP_CATALOG[@]}"; do
        IFS='|' read -r id _ _ pk _ <<< "$e"
        main=$(_app_main "$id" "$pk"); [[ -n "$main" ]] && names+=($main)
    done
    # pacman -T prints the ones that are NOT installed (exit 127 then); it also counts packages that provide the name
    missing=" $(pacman -T "${names[@]}" 2> /dev/null | tr '\n' ' ' || true) "
    for e in "${APP_CATALOG[@]}"; do
        IFS='|' read -r id _ _ pk _ <<< "$e"
        if [[ "$e" == *webapp* ]]; then [[ -f "$WEBAPP_DIR/waterbear-webapp-$id.desktop" ]] && APP_INSTALLED[$id]=1; continue; fi
        main=$(_app_main "$id" "$pk"); [[ -n "$main" ]] || continue
        for n in $main; do
            [[ "$missing" != *" $n "* ]] && { APP_INSTALLED[$id]=1; break; }
        done
    done
    return 0
}
app_is_installed() { [[ -n "${APP_INSTALLED[$1]:-}" ]]; }

# Make the saved app list match the system: installed apps are ticked, removed ones aren't
apps_reconcile() {
    command -v pacman > /dev/null || return 0
    apps_detect
    local e id pk
    for e in "${APP_CATALOG[@]}"; do
        IFS='|' read -r id _ _ pk _ <<< "$e"
        [[ -n "$pk" || "$id" == steam || "$e" == *webapp* ]] || continue
        if app_is_installed "$id"; then add_app "$id"; else del_app "$id"; fi
    done
    return 0
}

# Checklist options for one section: "label::id" (✓ = installed now)
app_options() {  # app_options [SECTION]
    local e id sec label flags tag
    for e in "${APP_CATALOG[@]}"; do
        IFS='|' read -r id sec label _ flags <<< "$e"
        [[ -n "${1:-}" && "$sec" != "$1" ]] && continue
        tag=""; [[ "$flags" == *aur* ]] && tag=" (AUR)"
        app_is_installed "$id" && tag+="  ✓ installed"
        printf '%s\n' "$label$tag::$id"
    done
}

section_ids() { local e id sec; for e in "${APP_CATALOG[@]}"; do IFS='|' read -r id sec _ <<< "$e"; [[ "$sec" == "$1" ]] && echo "$id"; done; }

# Tick / untick the apps of one section; the rest of your apps stay as they are
apps_section() {  # apps_section SECTION
    apps_reconcile
    local opts=() sel keep="" id
    mapfile -t opts < <(app_options "$1")
    sel=$(ui_checks "$1" "$APPS" "${opts[@]}") || return 1
    for id in $APPS; do [[ " $(section_ids "$1" | tr '\n' ' ') " == *" $id "* ]] || keep+="$id "; done
    need_sudo
    apps_sync "$keep$sel"
}

# ---------------------------------------------------------------------------
# Installing: official repos first, the AUR (through yay) for the rest
# ---------------------------------------------------------------------------
install_yay() {
    command -v yay > /dev/null && { ok "yay is already installed."; YAY=yes; return 0; }
    step "Installing yay (AUR helper)"
    pac git base-devel
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    if command -v yay > /dev/null; then ok "yay installed."; YAY=yes; else warn "yay didn't install. AUR apps will be skipped."; fi
}

aur_ready() {  # yay is there, or you said yes to installing it
    command -v yay > /dev/null && return 0
    ui_confirm "This comes from the AUR, which needs yay (an AUR helper). Install yay?" y || return 1
    install_yay
    command -v yay > /dev/null
}

pkgs_install() {  # pkgs_install PKG... (PKG may be "repo-name/aur-name")
    local repo=() aur=() p alt
    for p in "$@"; do
        if [[ "$p" == */* ]]; then alt="${p#*/}"; p="${p%%/*}"; else alt="$p"; fi
        if pacman -Si "$p" > /dev/null 2>&1; then repo+=("$p"); else aur+=("$alt"); fi
    done
    if (( ${#repo[@]} )); then pac "${repo[@]}" || return 1; fi
    if (( ${#aur[@]} )); then
        aur_ready || { warn "Skipped (needs yay): ${aur[*]}"; return 1; }
        yay -S --needed --noconfirm "${aur[@]}" || return 1
    fi
    return 0
}

install_app() {
    local id="$1" pkgs flags
    pkgs=$(app_field "$id" 4); flags=$(app_field "$id" 5)
    step "Installing $(app_field "$id" 3)"
    if [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        pkgs_install $pkgs || { warn "Install failed."; return 1; }
    fi
    if [[ "$flags" == *hook* ]]; then "app_hook_$id" || warn "Setup step for $id had a problem."; fi
    add_app "$id"
    ok "Done."
}

remove_app() {
    local id="$1" pkgs flags
    pkgs=$(app_field "$id" 4); flags=$(app_field "$id" 5)
    step "Removing $(app_field "$id" 3)"
    if [[ "$id" == steam ]]; then
        warn "Steam stays installed (removing GPU drivers automatically isn't safe). Use: sudo pacman -Rns steam"
    elif [[ -n "$pkgs" ]]; then
        # Remove the app itself; shared helpers (git, gcc, ripgrep...) stay installed.
        # The power tools pack is all standalone tools, so those all go.
        local p targets
        if [[ "$id" == powertools ]]; then targets="$pkgs"; else targets="${pkgs%% *}"; fi
        for p in ${targets//\// }; do
            pacman -Q "$p" > /dev/null 2>&1 && { sudo pacman -Rns --noconfirm "$p" 2>/dev/null || sudo pacman -R --noconfirm "$p" || true; }
        done
    fi
    [[ "$id" == localsend ]] && fw_apply_quiet
    if declare -F "app_unhook_$id" > /dev/null; then "app_unhook_$id" || true; fi
    del_app "$id"
    ok "Removed."
}

# Apply a new app selection: install what's newly ticked, offer to remove what got unticked
apps_sync() {  # apps_sync "new selection"
    local want="$1" id
    for id in $want; do has_app "$id" || install_app "$id"; done
    local removed=()
    for id in $APPS; do [[ " $want " == *" $id "* ]] || removed+=("$id"); done
    if [[ ${#removed[@]} -gt 0 ]]; then
        if ui_confirm "Remove these unticked apps? ${removed[*]}" n; then
            for id in "${removed[@]}"; do remove_app "$id"; done
        else
            for id in "${removed[@]}"; do del_app "$id"; done   # just stop tracking them
        fi
    fi
}

# --- per-app setup hooks -----------------------------------------------------

app_hook_nvim() {
    if [[ -d "$HOME/.config/nvim" ]]; then
        info "~/.config/nvim already exists, so LazyVim wasn't installed over it."
    else
        if git clone --depth 1 https://github.com/LazyVim/starter "$HOME/.config/nvim"; then
            rm -rf "$HOME/.config/nvim/.git"
            info "LazyVim installed. Open nvim once and it downloads its plugins."
        else
            warn "Couldn't download LazyVim (no internet?). Neovim is installed; re-run it from Install → Editors later."
            return 1
        fi
    fi
    scheme_load "$SCHEME"
    [[ -d "$HOME/.config/nvim/lua/plugins" ]] && render nvim/waterbear-theme.lua "$HOME/.config/nvim/lua/plugins/waterbear-theme.lua"
    return 0
}

app_hook_docker() {
    sudo systemctl enable --now docker.service
    sudo usermod -aG docker "$USER"
    info "Log out and back in to use docker without sudo."
}

app_hook_localsend() {
    add_app localsend
    fw_apply_quiet
}

app_hook_duckduckgo() {
    webapp_write DuckDuckGo "https://duckduckgo.com" duckduckgo
    SEARCH=duckduckgo
    info "DuckDuckGo is in your app launcher, and Super+S now searches DuckDuckGo."
    info "In your browser: Settings → Search → Default search engine → DuckDuckGo."
}
app_unhook_duckduckgo() {
    rm -f "$WEBAPP_DIR/waterbear-webapp-duckduckgo.desktop"
    SEARCH=google
}

app_hook_rust() {
    rustup default stable || warn "Run 'rustup default stable' yourself to finish setting up Rust."
}

app_hook_steam() {
    "$WB_HOME/bin/steam-setup.sh" $($INTERACTIVE || echo --yes)
}

# ---------------------------------------------------------------------------
# Search any package (official repos, plus the AUR with yay) / remove packages
# ---------------------------------------------------------------------------
fzf_theme() {  # fzf colors from the current theme
    printf '%s' "--color=fg:#$P_FG,hl:#$P_A,fg+:#$P_B,bg+:#$P_C0,hl+:#$P_A,prompt:#$P_A,pointer:#$P_B,marker:#$P_A,header:#$P_DIM,info:#$P_DIM,border:#$P_C8,spinner:#$P_A"
}

pkg_search() {  # pkg_search repo|aur
    command -v fzf > /dev/null || { need_sudo; pac fzf; }
    local list=(pacman -Slq) preview="pacman -Si {}" where="official repos"
    if [[ "$1" == aur ]]; then
        aur_ready || return 0
        list=(yay -Slq); preview="yay -Si {}"; where="official repos + AUR"
    fi
    info "Loading the package list ($where)..."
    local sel
    sel=$("${list[@]}" 2> /dev/null | sort -u | fzf --multi --layout=reverse --height=100% --prompt "install ❯ " \
        --header "type to search · tab = pick several · enter = install · esc = back  ($where)" \
        --preview "$preview" --preview-window 'right,55%,wrap' --bind 'left:abort' "$(fzf_theme)") || return 0
    [[ -n "$sel" ]] || return 0
    local pkgs; pkgs=$(tr '\n' ' ' <<< "$sel")
    ui_confirm "Install: $pkgs?" y || return 0
    need_sudo
    # shellcheck disable=SC2086
    if pkgs_install $pkgs; then ok "Installed: $pkgs"; else warn "Something didn't install (scroll up for the error)."; fi
    apps_reconcile; state_save
    ui_pause
}

pkg_remove() {
    command -v fzf > /dev/null || { need_sudo; pac fzf; }
    local sel
    sel=$(pacman -Qeq | fzf --multi --layout=reverse --height=100% --prompt "remove ❯ " \
        --header "packages you installed · tab = pick several · enter = remove · esc = back" \
        --preview 'pacman -Qi {}' --preview-window 'right,55%,wrap' --bind 'left:abort' "$(fzf_theme)") || return 0
    [[ -n "$sel" ]] || return 0
    local pkgs; pkgs=$(tr '\n' ' ' <<< "$sel")
    ui_confirm "Remove: $pkgs? (and what only they needed)" n || return 0
    need_sudo
    # shellcheck disable=SC2086
    sudo pacman -Rns --noconfirm $pkgs || warn "pacman couldn't remove them (scroll up for why)."
    apps_reconcile; state_save
    ui_pause
}

# ---------------------------------------------------------------------------
# Web apps: a website in its own window, with its own launcher entry. Starts empty; you add them.
# ---------------------------------------------------------------------------
WEBAPP_DIR="$HOME/.local/share/applications"

webapp_open() {  # webapp_open URL — in a Chromium-based browser as an app window, else Firefox
    local b
    for b in chromium brave google-chrome-stable vivaldi-stable vivaldi microsoft-edge-stable; do
        command -v "$b" > /dev/null && exec "$b" --app="$1"
    done
    command -v firefox > /dev/null && exec firefox --new-window "$1"
    exec xdg-open "$1"
}

webapp_list() {  # prints "file<TAB>name<TAB>url" for each web app you added
    local f name url
    for f in "$WEBAPP_DIR"/waterbear-webapp-*.desktop; do
        [[ -f "$f" ]] || continue
        name=$(sed -n 's/^Name=//p' "$f" | head -n1); url=$(sed -n 's/^X-Waterbear-URL=//p' "$f" | head -n1)
        printf '%s\t%s\t%s\n' "$f" "$name" "$url"
    done
}

webapp_write() {  # webapp_write NAME URL SLUG — the launcher entry for a web app
    local name="$1" url="$2" slug="$3" icon=web-browser f
    [[ -f "/usr/share/icons/Papirus/64x64/apps/$slug.svg" ]] && icon="$slug"
    f="$WEBAPP_DIR/waterbear-webapp-$slug.desktop"
    mkdir -p "$WEBAPP_DIR"
    cat > "$f" << DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Comment=Web app: $url (added in Waterbear → Install → Web apps)
Exec=waterbear webapp-open "$url"
Icon=$icon
Categories=Network;WebBrowser;
X-Waterbear-URL=$url
DESKTOP
}

webapp_add() {
    local name url slug
    name=$(ui_input "Web app name" "" "e.g. YouTube") || return 0
    name="${name//[$'\t\r\n']/}"; [[ -n "${name// /}" ]] || return 0
    url=$(ui_input "Address for $name" "https://") || return 0
    [[ "$url" =~ ^https?://[^[:space:]]+\.[^[:space:]]+$ ]] || { warn "'$url' doesn't look like a web address (https://...)."; ui_pause; return 0; }
    slug=$(tr '[:upper:]' '[:lower:]' <<< "$name" | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//')
    [[ -n "$slug" ]] || slug="app$RANDOM"
    webapp_write "$name" "$url" "$slug"
    ok "Added $name. It's in your app launcher now."
    local b found=""
    for b in chromium brave google-chrome-stable vivaldi-stable vivaldi microsoft-edge-stable; do command -v "$b" > /dev/null && found=$b && break; done
    [[ -z "$found" ]] && info "Tip: with a Chromium-based browser (Install → Browsers) web apps open in their own window; Firefox opens them as a normal window."
    ui_pause
}

webapps_menu() {
    while true; do
        ui_title "Web apps"
        local opts=() line f name url
        while IFS=$'\t' read -r f name url; do opts+=("$name  ${url}::$f"); done < <(webapp_list)
        [[ ${#opts[@]} -eq 0 ]] && info "No web apps yet. Add one: a website that opens in its own window." && echo
        local c
        c=$(ui_pick "Web apps" add "${opts[@]}" "-- " "+ Add a web app (name + address)::add") || return 0
        if [[ "$c" == add ]]; then webapp_add; continue; fi
        name=$(sed -n 's/^Name=//p' "$c" | head -n1); url=$(sed -n 's/^X-Waterbear-URL=//p' "$c" | head -n1)
        local act
        act=$(ui_pick "$name  ($url)" open "Open it::open" "Remove it::remove") || continue
        case "$act" in
            open)   (setsid "$WB_HOME/waterbear" webapp-open "$url" > /dev/null 2>&1 &) ;;
            remove) ui_confirm "Remove the web app $name?" n && rm -f "$c" && ok "Removed $name." && ui_pause ;;
        esac
    done
}
