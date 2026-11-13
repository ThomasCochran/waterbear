# lib/apps.sh — the app catalog, installed-app detection, package search, web apps.
# Each catalog entry: id|section|label|packages|flags
#   packages: "name" or "name/aur-name" (the repo package when the repos have it, otherwise that AUR package)
#   flags: aur = usually from the AUR (installs yay when needed) · hook = runs app_hook_<id> after installing
#          none = no packages (Waterbear-only extras) · webapp = a web app Waterbear makes (installed = its launcher exists)
APP_SECTIONS=(Browsers Editors "Dev tools" "AI tools" Terminal "Media & creative" "Office & notes" Sharing Gaming Extras)
APP_CATALOG=(
 "firefox|Browsers|Firefox|firefox|"
 "chromium|Browsers|Chromium (also runs web apps in their own window)|chromium|"
 "brave|Browsers|Brave|brave-bin|aur"
 "zen|Browsers|Zen Browser|zen-browser-bin|aur"
 "tor|Browsers|Tor Browser (private browsing over Tor · downloads and checks Tor Browser on first start)|torbrowser-launcher|"
 "duckduckgo|Browsers|DuckDuckGo (a DuckDuckGo window · browsers start on DuckDuckGo · Super+S searches it)||none webapp hook"
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
 "ssh|Dev tools|SSH client + a key (for GitHub and servers · to let others in: System → Firewall → SSH)|openssh|hook"
 "java|Dev tools|Java (OpenJDK)|jdk-openjdk|"
 "cpp|Dev tools|C / C++ (gcc · clang · cmake · gdb)|gcc clang cmake gdb|"
 "zig|Dev tools|Zig|zig|"
 "virtualbox|Dev tools|VirtualBox (virtual machines)|virtualbox virtualbox-host-dkms|hook"
 "claude|AI tools|Claude Code (Anthropic's coding agent in the terminal)|claude-code|aur"
 "opencode|AI tools|OpenCode (open-source coding agent, works with many AI providers)|opencode/opencode-bin|"
 "gemini|AI tools|Gemini CLI (Google)|gemini-cli|"
 "codex|AI tools|Codex CLI (OpenAI)|openai-codex|"
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
 "officefonts|Office & notes|Office fonts + spell-check (Word / PowerPoint files keep their layout)|ttf-liberation ttf-carlito ttf-caladea ttf-dejavu hunspell hunspell-en_us|"
 "obsidian|Office & notes|Obsidian (notes)|obsidian|"
 "localsend|Sharing|LocalSend (send files between your phone and computer)|localsend/localsend-bin|hook"
 "kdeconnect|Sharing|KDE Connect (phone integration · open its ports in System → Firewall)|kdeconnect|"
 "steam|Gaming|Steam + GPU drivers + Proton-GE + GameMode + MangoHud||none hook"
 "lutris|Gaming|Lutris (GOG, Battle.net, emulators… + GPU drivers)|lutris|hook"
 "heroic|Gaming|Heroic (Epic · GOG · Amazon games + GPU drivers)|heroic-games-launcher-bin|aur hook"
 "prism|Gaming|Prism Launcher (Minecraft)|prismlauncher|"
 "cmatrix|Extras|cmatrix (Matrix rain)|cmatrix|"
 "cava|Extras|cava (music visualizer)|cava|"
 "clock|Extras|Terminal clock (type: clock)||none"
)

app_field() {  # app_field ID N  (1=id 2=section 3=label 4=packages 5=flags)
    local e; for e in "${APP_CATALOG[@]}"; do
        [[ "${e%%|*}" == "$1" ]] && { echo "$e" | cut -d'|' -f"$2"; return 0; }
    done
}

# Bundles: a few apps picked together. id|name|app ids. A bundle only ever adds apps.
APP_BUNDLES=(
 "programmer|Programmer|nvim vscode python node rust go docker lazygit ghcli ssh powertools tmux btop claude"
 "work|Work PC|firefox libreoffice officefonts obsidian localsend signal"
 "gamer|Gamer|steam lutris heroic prism discord obs"
)
bundle_field() {  # bundle_field ID N  (1=id 2=name 3=apps)
    local b; for b in "${APP_BUNDLES[@]}"; do
        [[ "${b%%|*}" == "$1" ]] && { cut -d'|' -f"$2" <<< "$b"; return 0; }
    done
    return 1
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

# Tick a bundle's apps (all ticked to start); installs what's ticked, never removes anything
apps_bundle() {  # apps_bundle ID
    local name ids id opts=() sel
    name=$(bundle_field "$1" 2) || { warn "No bundle called '$1'. Bundles: $(printf '%s ' "${APP_BUNDLES[@]%%|*}")"; return 1; }
    ids=$(bundle_field "$1" 3)
    apps_reconcile
    for id in $ids; do
        local tag=""; [[ "$(app_field "$id" 5)" == *aur* ]] && tag=" (AUR)"
        app_is_installed "$id" && tag+="  ✓ installed"
        opts+=("$(app_field "$id" 3)$tag::$id")
    done
    sel=$(ui_checks "Bundle: $name" "$ids" "${opts[@]}") || return 1
    [[ -n "${sel// /}" ]] || return 1
    need_sudo
    apps_sync "$APPS $sel"   # everything you have stays in the list, so nothing is offered for removal
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
    browser_policies_apply
    info "DuckDuckGo is in your app launcher, and Super+S now searches DuckDuckGo."
    info "Firefox, Chromium and Brave now start on DuckDuckGo (restart them if they're open)."
    info "Firefox's search bar: Settings → Search → Default search engine → DuckDuckGo."
}
app_unhook_duckduckgo() {
    rm -f "$WEBAPP_DIR/waterbear-webapp-duckduckgo.desktop"
    SEARCH=google
    browser_policies_apply
}

app_hook_ssh() {
    local key="$HOME/.ssh/id_ed25519"
    if [[ -f "$key" ]]; then
        info "You already have an SSH key ($key)."
    elif $INTERACTIVE; then
        info "Making your SSH key. A passphrase protects it if someone copies the file (Enter = none)."
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        ssh-keygen -t ed25519 -C "$(id -un)@$(uname -n)" -f "$key" || { warn "No key made. Run: ssh-keygen -t ed25519"; return 1; }
    else
        info "Make an SSH key any time with: ssh-keygen -t ed25519"; return 0
    fi
    info "Your public key (safe to share; paste it in GitHub → Settings → SSH keys, or a server's ~/.ssh/authorized_keys):"
    echo; cat "$key.pub"; echo
}

app_hook_virtualbox() {
    # VirtualBox's kernel driver is built by DKMS for each kernel, which needs that kernel's headers
    local k kernels=()
    mapfile -t kernels < <(pacman -Qq linux linux-lts linux-zen linux-hardened linux-cachyos 2> /dev/null || true)
    for k in "${kernels[@]}"; do pkg_installed "$k-headers" || pac "$k-headers" || warn "Couldn't install $k-headers."; done
    sudo dkms autoinstall > /dev/null 2>&1 || true
    sudo usermod -aG vboxusers "$USER"
    sudo modprobe vboxdrv 2> /dev/null || true
    info "Restart your computer before the first virtual machine (the driver and your vboxusers group need it)."
}

GAME_DRIVERS_DONE=false
game_drivers() {  # multilib + GPU drivers + GameMode/MangoHud, once (Steam's setup does it too)
    $GAME_DRIVERS_DONE && return 0
    if app_is_installed steam || has_app steam; then GAME_DRIVERS_DONE=true; return 0; fi
    "$WB_HOME/bin/steam-setup.sh" --drivers-only $($INTERACTIVE || echo --yes) && GAME_DRIVERS_DONE=true
}
app_hook_lutris() { game_drivers; }
app_hook_heroic() { game_drivers; }

app_hook_rust() {
    rustup default stable || warn "Run 'rustup default stable' yourself to finish setting up Rust."
}

app_hook_steam() {
    "$WB_HOME/bin/steam-setup.sh" $($INTERACTIVE || echo --yes) && GAME_DRIVERS_DONE=true
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

exec_quote() {  # exec_quote STRING — STRING as a quoted Exec= argument (desktop entry spec)
    # % is written %%, and " ` $ \\ are escaped inside the quotes
    local v="${1//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//\`/\\\`}"; v="${v//\$/\\\$}"
    printf '"%s"' "${v//%/%%}"
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
Exec=$(exec_quote "$WB_BIN/waterbear") webapp-open $(exec_quote "$url")
Icon=$icon
Categories=Network;WebBrowser;
X-Waterbear-URL=$url
DESKTOP
}

# Older launchers ran a bare `waterbear`, which isn't on the desktop's PATH
# (~/.local/bin is only added by your shell), so the app launcher showed "failed to execute".
webapps_fix_exec() {
    local f name url
    while IFS=$'\t' read -r f name url; do
        grep -q '^Exec=waterbear ' "$f" || continue
        f="${f##*/waterbear-webapp-}"; webapp_write "$name" "$url" "${f%.desktop}"
    done < <(webapp_list)
}

webapp_add() {
    local name url slug
    name=$(ui_input "Web app name" "" "e.g. YouTube") || return 0
    name="${name//[$'\t\r\n']/}"; [[ -n "${name// /}" ]] || return 0
    url=$(ui_input "Address for $name" "https://") || return 0
    [[ "$url" =~ ^https?://[^[:space:]]+\.[^[:space:]]+$ ]] || { warn "'$url' doesn't look like a web address (https://...)."; ui_pause; return 0; }
    slug=$(webapp_slug "$name")
    webapp_write "$name" "$url" "$slug"
    ok "Added $name. It's in your app launcher now."
    local b found=""
    for b in chromium brave google-chrome-stable vivaldi-stable vivaldi microsoft-edge-stable; do command -v "$b" > /dev/null && found=$b && break; done
    [[ -z "$found" ]] && info "Tip: with a Chromium-based browser (Install → Browsers) web apps open in their own window; Firefox opens them as a normal window."
    ui_pause
}

# Common web apps: slug|name|address. Ticked = its launcher exists.
WEBAPP_PRESETS=(
 "youtube|YouTube|https://www.youtube.com"
 "gmail|Gmail|https://mail.google.com"
 "google-calendar|Google Calendar|https://calendar.google.com"
 "google-drive|Google Drive|https://drive.google.com"
 "google-docs|Google Docs|https://docs.google.com"
 "outlook|Outlook|https://outlook.live.com/mail"
 "office|Microsoft 365|https://www.office.com"
 "whatsapp|WhatsApp|https://web.whatsapp.com"
 "claude|Claude|https://claude.ai"
 "chatgpt|ChatGPT|https://chatgpt.com"
 "notion|Notion|https://www.notion.so"
 "github|GitHub|https://github.com"
 "netflix|Netflix|https://www.netflix.com"
 "twitch|Twitch|https://www.twitch.tv"
)

webapps_common() {
    local e slug name url on="" opts=() sel
    for e in "${WEBAPP_PRESETS[@]}"; do
        IFS='|' read -r slug name url <<< "$e"
        [[ -f "$WEBAPP_DIR/waterbear-webapp-$slug.desktop" ]] && on+="$slug "
        opts+=("$(printf '%-16s' "$name") ${url#https://}::$slug")
    done
    sel=$(ui_checks "Common web apps (ticked = in your app launcher)" "$on" "${opts[@]}") || return 0
    for e in "${WEBAPP_PRESETS[@]}"; do
        IFS='|' read -r slug name url <<< "$e"
        if [[ " $sel " == *" $slug "* ]]; then
            [[ " $on " == *" $slug "* ]] || { webapp_write "$name" "$url" "$slug"; ok "Added $name."; }
        elif [[ " $on " == *" $slug "* ]]; then
            rm -f "$WEBAPP_DIR/waterbear-webapp-$slug.desktop"; ok "Removed $name."
        fi
    done
    ui_pause
}

webapp_slug() {  # webapp_slug NAME — a file-name-safe slug that no web app uses yet
    local base slug n=2
    base=$(tr '[:upper:]' '[:lower:]' <<< "$1" | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-40)
    [[ -n "$base" ]] || base="app"
    slug="$base"
    while [[ -f "$WEBAPP_DIR/waterbear-webapp-$slug.desktop" ]]; do slug="$base-$n"; ((n++)); done
    echo "$slug"
}

# Bookmarks: export them from any browser as an HTML file (Firefox: Ctrl+Shift+O → Import and Backup →
# Export Bookmarks to HTML · Chrome/Brave: Bookmark manager → ⋮ → Export bookmarks), then drag the file
# onto the terminal: that types its path in.
webapps_import() {
    local file
    file=$(ui_input "Bookmarks file: drag it onto this window, or type its path, then Enter" "" "~/bookmarks.html") || return 0
    file="${file//\'/}"; file="${file//\"/}"; file="${file#file://}"; file="${file%"${file##*[![:space:]]}"}"; file="${file#"${file%%[![:space:]]*}"}"
    file="${file/#\~/$HOME}"; file="${file//\\ / }"
    if [[ ! -f "$file" ]]; then warn "Can't find '$file'."; ui_pause; return 0; fi
    local urls=() names=() opts=() i=0 url name
    while IFS=$'\t' read -r url name; do
        [[ -n "$url" ]] || continue
        [[ -n "${name// /}" ]] || { name="${url#*://}"; name="${name%%/*}"; }
        urls+=("$url"); names+=("$name"); opts+=("$(printf '%-30.30s' "$name") ${url#*://}::$i"); ((i++)) || true
    done < <(grep -oiE '<a [^>]*href="https?://[^"]+"[^>]*>[^<]*</a>' "$file" \
             | sed -E 's/.*[Hh][Rr][Ee][Ff]="([^"]+)"[^>]*>([^<]*)<\/[Aa]>.*/\1\t\2/' \
             | sed -E 's/&amp;/\&/g; s/&quot;//g; s/&#39;//g; s/&lt;//g; s/&gt;//g' | awk -F'\t' '!seen[$1]++')
    if (( i == 0 )); then warn "No web addresses found in that file (it should be a bookmarks .html export)."; ui_pause; return 0; fi
    local sel idx n=0
    sel=$(ui_checks "Bookmarks: tick the ones to make into web apps ($i found)" "" "${opts[@]}") || return 0
    for idx in $sel; do
        name="${names[$idx]//[$'\t\r\n\"']/}"
        webapp_write "$name" "${urls[$idx]}" "$(webapp_slug "$name")"; ((n++)) || true
    done
    ok "Added $n web app(s). They're in your app launcher."
    ui_pause
}

webapps_menu() {
    while true; do
        ui_title "Web apps"
        local opts=() line f name url
        while IFS=$'\t' read -r f name url; do opts+=("$name  ${url}::$f"); done < <(webapp_list)
        [[ ${#opts[@]} -eq 0 ]] && info "No web apps yet. Add one: a website that opens in its own window." && echo
        local c
        c=$(ui_pick "Web apps" add "${opts[@]}" "-- " "+ Add a web app (name + address)::add" \
            "+ Common web apps   YouTube · Gmail · Calendar · WhatsApp… (tick boxes)::common" \
            "+ From your bookmarks   pick from a bookmarks file you exported::import") || return 0
        case "$c" in
            add)    webapp_add; continue ;;
            common) webapps_common; continue ;;
            import) webapps_import; continue ;;
        esac
        name=$(sed -n 's/^Name=//p' "$c" | head -n1); url=$(sed -n 's/^X-Waterbear-URL=//p' "$c" | head -n1)
        local act
        act=$(ui_pick "$name  ($url)" open "Open it::open" "Remove it::remove") || continue
        case "$act" in
            open)   (setsid "$WB_HOME/waterbear" webapp-open "$url" > /dev/null 2>&1 &) ;;
            remove) ui_confirm "Remove the web app $name?" n && rm -f "$c" && ok "Removed $name." && ui_pause ;;
        esac
    done
}
