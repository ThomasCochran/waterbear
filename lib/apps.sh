# lib/apps.sh — the optional app catalog. Each entry: id|section|label|packages|flags
# flags: aur = needs yay · hook = runs app_hook_<id> after installing · none = no packages
APP_CATALOG=(
 "nvim|Coding|Neovim + LazyVim (Vim as an IDE)|neovim git ripgrep fd fzf lazygit tree-sitter-cli gcc|hook"
 "vscode|Coding|VS Code (open-source build)|code|"
 "python|Coding|Python + pipx (latest)|python python-pipx|"
 "node|Coding|Node.js + npm (latest)|nodejs npm|"
 "lazygit|Coding|lazygit (Git in the terminal)|lazygit|"
 "docker|Coding|Docker + Compose|docker docker-compose|hook"
 "btop|Terminal|btop (system monitor)|btop|"
 "htop|Terminal|htop (classic monitor)|htop|"
 "powertools|Terminal|Power tools (fzf · ripgrep · bat · eza · zoxide)|fzf ripgrep bat eza zoxide fd|"
 "yazi|Terminal|yazi (file manager in the terminal)|yazi|"
 "tmux|Terminal|tmux (split terminals)|tmux|"
 "ddgr|Terminal|ddgr (web search in the terminal)|ddgr|"
 "discord|Everyday|Discord|discord|"
 "obsidian|Everyday|Obsidian (notes)|obsidian|"
 "spotify|Everyday|Spotify|spotify-launcher|"
 "mpv|Everyday|mpv (video player)|mpv|"
 "libreoffice|Everyday|LibreOffice|libreoffice-fresh|"
 "gimp|Everyday|GIMP (image editor)|gimp|"
 "obs|Everyday|OBS Studio (screen recording)|obs-studio|"
 "localsend|Everyday|LocalSend (phone ↔ laptop files · needs yay)|localsend-bin|aur hook"
 "steam|Gaming|Steam + GPU drivers + Proton-GE + GameMode + MangoHud||none hook"
 "cmatrix|Looks|cmatrix (Matrix rain)|cmatrix|"
 "cava|Looks|cava (music visualizer)|cava|"
 "clock|Looks|Terminal clock (type: clock)||none"
)

app_field() {  # app_field ID N  (1=id 2=section 3=label 4=packages 5=flags)
    local e; for e in "${APP_CATALOG[@]}"; do
        [[ "${e%%|*}" == "$1" ]] && { echo "$e" | cut -d'|' -f"$2"; return 0; }
    done
}

# Checklist options "label::id"; LocalSend only shows when yay is on
app_options() {
    local e id sec label flags
    for e in "${APP_CATALOG[@]}"; do
        IFS='|' read -r id sec label _ flags <<< "$e"
        [[ "$flags" == *aur* && "$YAY" != yes ]] && continue
        printf '%s\n' "$(printf '%-9s' "$sec")  $label::$id"
    done
}

install_yay() {
    command -v yay > /dev/null && { ok "yay is already installed."; return 0; }
    step "Installing yay (AUR helper)"
    pac git base-devel
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    command -v yay > /dev/null && ok "yay installed." || warn "yay didn't install. AUR apps will be skipped."
}

install_app() {
    local id="$1" pkgs flags
    pkgs=$(app_field "$id" 4); flags=$(app_field "$id" 5)
    step "Installing $(app_field "$id" 3)"
    if [[ "$flags" == *aur* ]]; then
        command -v yay > /dev/null || { warn "Needs yay (turn it on in System). Skipped."; return 1; }
        # shellcheck disable=SC2086
        yay -S --needed --noconfirm $pkgs || { warn "Install failed."; return 1; }
    elif [[ -n "$pkgs" ]]; then
        # shellcheck disable=SC2086
        pac $pkgs || { warn "Install failed."; return 1; }
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
        for p in $targets; do
            pkg_installed "$p" && { sudo pacman -Rns --noconfirm "$p" 2>/dev/null || sudo pacman -R --noconfirm "$p" || true; }
        done
    fi
    [[ "$id" == localsend ]] && fw_apply_quiet
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
            warn "Couldn't download LazyVim (no internet?). Neovim is installed; re-run from the Apps menu later."
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

app_hook_steam() {
    "$WB_HOME/bin/steam-setup.sh" $($INTERACTIVE || echo --yes)
}
