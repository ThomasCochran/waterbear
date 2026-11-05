# lib/system.sh — Snapper, login style, firewall, update, snapshots.

# ---------------------------------------------------------------------------
# Snapper
# ---------------------------------------------------------------------------
snapper_setup() {
    if [[ "$(findmnt -no FSTYPE /)" != btrfs ]]; then
        warn "Your root filesystem isn't btrfs, so Snapper can't be used. Skipping."
        SNAPPER=no; SNAPPER_WEEKLY=no; return 0
    fi
    step "Snapper"
    pac snapper grub-btrfs inotify-tools pacman-contrib btrfs-assistant
    if [[ ! -f /etc/snapper/configs/root ]]; then
        # archinstall already made a /.snapshots subvolume, which makes create-config fail.
        local had_mount=false
        if mountpoint -q /.snapshots; then
            had_mount=true; sudo umount /.snapshots; sudo rmdir /.snapshots
        fi
        sudo snapper -c root create-config /
        if $had_mount; then
            sudo btrfs subvolume delete /.snapshots
            sudo mkdir /.snapshots; sudo mount /.snapshots; sudo chmod 750 /.snapshots
        fi
    fi
    sudo sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' /etc/snapper/configs/root
    sudo systemctl enable --now snapper-cleanup.timer
    # No snapshot on every pacman run (mask snap-pac's hooks in case it ever gets installed)
    sudo mkdir -p /etc/pacman.d/hooks
    local h; for h in 05-snap-pac-pre 10-snap-pac-removal zz-snap-pac-post; do
        sudo ln -sf /dev/null "/etc/pacman.d/hooks/$h.hook"
    done
    if [[ -d /boot/grub ]]; then
        sudo systemctl enable --now grub-btrfsd
        sudo grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>&1 && info "Snapshots added to the GRUB menu."
    fi
    weekly_snapshot_set "$SNAPPER_WEEKLY"
    ok "Snapper ready."
}

# Weekly snapshot at login: root-owned script + service + a sudoers rule for that one command
weekly_snapshot_set() {  # yes|no
    if [[ "$1" == yes ]]; then
        sudo install -Dm755 -o root -g root "$WB_HOME/system/auto-snapshot.sh" /usr/local/bin/auto-snapshot.sh
        sudo install -Dm644 -o root -g root "$WB_HOME/system/weekly-snapshot.service" /etc/systemd/system/weekly-snapshot.service
        local tmp; tmp=$(mktemp)
        printf '%s ALL=(root) NOPASSWD: /usr/bin/systemctl start --no-block weekly-snapshot.service\n' "$(id -un)" > "$tmp"
        if sudo visudo -cf "$tmp" > /dev/null; then
            sudo install -m440 -o root -g root "$tmp" /etc/sudoers.d/weekly-snapshot
        else
            warn "sudoers rule failed validation; weekly snapshots won't start at login."
        fi
        rm -f "$tmp"
        sudo systemctl daemon-reload
        ln -sf "$WB_HOME/bin/weekly-snapshot-login.sh" "$WB_BIN/weekly-snapshot-login.sh"
        info "Weekly snapshot: on (checked at each login, keeps the newest 3)."
    else
        rm -f "$WB_BIN/weekly-snapshot-login.sh"
        sudo rm -f /etc/sudoers.d/weekly-snapshot
        info "Weekly snapshot: off."
    fi
}

snapshot_now() {  # snapshot_now DESCRIPTION
    [[ -f /etc/snapper/configs/root ]] || { warn "Snapper isn't set up."; return 1; }
    sudo snapper -c root create -d "$1" && ok "Snapshot '$1' created."
}

snapshots_menu() {
    [[ -f /etc/snapper/configs/root ]] || { warn "Snapper isn't set up. Turn it on in System."; ui_pause; return; }
    ui_title "Snapshots"
    sudo snapper -c root list
    echo
    local act
    act=$(ui_pick "Snapshots" back "Take a snapshot now::new" "Open the snapshot app (btrfs-assistant)::gui" "Back::back") || return
    case "$act" in
        new) local d; d=$(ui_input "Description" "manual-$(date +%F)") && snapshot_now "$d"; ui_pause ;;
        gui) (setsid btrfs-assistant > /dev/null 2>&1 &) ;;
    esac
    info "To roll back: reboot, pick a snapshot in the GRUB menu, then restore it with btrfs-assistant."
}

# ---------------------------------------------------------------------------
# Login: text login on tty1 (default) or hyprlock as the login screen
# ---------------------------------------------------------------------------
login_apply() {
    step "Login: $([[ $LOGIN == screen ]] && echo "hyprlock login screen" || echo "text login on tty1")"
    if [[ "$LOGIN" == screen ]]; then
        pac greetd
        sed "s/@@LOGIN_USER@@/$(id -un)/" "$WB_HOME/system/greetd-config.toml" > /tmp/wb-greetd.toml
        sudo install -Dm644 /tmp/wb-greetd.toml /etc/greetd/config.toml; rm -f /tmp/wb-greetd.toml
        if grep -q 'start Hyprland on tty1' "$HOME/.bash_profile" 2>/dev/null; then
            sed -i '/^# .*start Hyprland on tty1$/,/^fi$/d' "$HOME/.bash_profile"
        fi
        sudo systemctl disable getty@tty1.service > /dev/null 2>&1 || true
        sudo systemctl enable greetd.service
        info "Takes effect on the next boot."
    else
        if systemctl is-enabled --quiet greetd.service 2>/dev/null; then
            sudo systemctl disable greetd.service
            sudo systemctl enable getty@tty1.service
        fi
        if ! grep -q 'start Hyprland on tty1' "$HOME/.bash_profile" 2>/dev/null; then
            cat >> "$HOME/.bash_profile" << 'PROFILE'

# Waterbear: start Hyprland on tty1
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == /dev/tty1 ]]; then
    exec start-hyprland
fi
PROFILE
        else
            sed -i 's/^\(\s*\)exec Hyprland$/\1exec start-hyprland/' "$HOME/.bash_profile"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Firewall (ufw): block incoming by default, open only what you tick
# ---------------------------------------------------------------------------
FW_OPTIONS=(
 "SSH (port 22) — connect to this computer remotely::ssh"
 "Steam Remote Play / in-home streaming::steam"
 "Dev servers on your network (3000 · 5173 · 8000 · 8080)::dev"
 "KDE Connect / GSConnect (phone integration)::kdeconnect"
)

fw_apply() {
    step "Firewall"
    if [[ "$FIREWALL" != yes ]]; then
        command -v ufw > /dev/null && { sudo ufw disable > /dev/null; sudo systemctl disable --now ufw > /dev/null 2>&1; }
        info "Firewall off: everything allowed."
        return 0
    fi
    pac ufw
    sudo ufw --force reset > /dev/null
    sudo ufw default deny incoming > /dev/null
    sudo ufw default allow outgoing > /dev/null
    local p; for p in $FW_PORTS; do
        case "$p" in
            ssh)        pac openssh; sudo systemctl enable --now sshd > /dev/null 2>&1
                        sudo ufw limit 22/tcp > /dev/null; info "Open: SSH (22, with brute-force limiting)" ;;
            steam)      sudo ufw allow 27031:27036/udp > /dev/null; sudo ufw allow 27036:27037/tcp > /dev/null
                        info "Open: Steam Remote Play" ;;
            dev)        local port; for port in 3000 5173 8000 8080; do sudo ufw allow from 192.168.0.0/16 to any port $port proto tcp > /dev/null
                        sudo ufw allow from 10.0.0.0/8 to any port $port proto tcp > /dev/null; done
                        info "Open on your local network only: 3000, 5173, 8000, 8080" ;;
            kdeconnect) sudo ufw allow 1714:1764/udp > /dev/null; sudo ufw allow 1714:1764/tcp > /dev/null
                        info "Open: KDE Connect" ;;
        esac
    done
    if has_app localsend; then
        sudo ufw allow 53317/tcp > /dev/null; sudo ufw allow 53317/udp > /dev/null
        info "Open: LocalSend (53317)"
    fi
    sudo ufw --force enable > /dev/null
    sudo systemctl enable ufw > /dev/null 2>&1
    ok "Firewall on: incoming blocked except the ports above."
}
fw_apply_quiet() { [[ "$FIREWALL" == yes ]] && command -v ufw > /dev/null && fw_apply > /dev/null; return 0; }

# ---------------------------------------------------------------------------
# Screensaver & lock timing
# ---------------------------------------------------------------------------
idle_preset() {  # idle_preset short|normal|long  -> sets IDLE_* (saver lock off suspend, minutes)
    case "$1" in
        short)  IDLE_SAVER=2; IDLE_LOCK=3;  IDLE_OFF=5;  IDLE_SUSPEND=15 ;;
        normal) IDLE_SAVER=4; IDLE_LOCK=5;  IDLE_OFF=7;  IDLE_SUSPEND=20 ;;
        long)   IDLE_SAVER=9; IDLE_LOCK=10; IDLE_OFF=15; IDLE_SUSPEND=30 ;;
    esac
    IDLE_PRESET="$1"
}

# ---------------------------------------------------------------------------
# Update: snapshot → system update → newest Waterbear → re-apply configs
# Every step that fails is collected and shown in a red box at the very end (and as a
# desktop notification, and in ~/.cache/waterbear/last-update.log), so it can't scroll by unseen.
# ---------------------------------------------------------------------------
WB_UPDATE_LOG="${XDG_CACHE_HOME:-$HOME/.cache}/waterbear/last-update.log"

# Gets the newest Waterbear into $WB_HOME. On failure: prints why, sets WB_UPDATE_ERR, returns 1.
wb_self_update() {
    WB_UPDATE_ERR=""
    local out
    if [[ -d "$WB_HOME/.git" ]]; then
        # Files edited (or added) by hand inside the install folder make `git pull` refuse to update
        local dirty; dirty=$(git -C "$WB_HOME" status --porcelain 2>&1) || true
        if [[ -n "$dirty" ]]; then
            warn "Waterbear's install folder has files that were changed by hand:"
            sed 's/^/      /' <<< "$dirty"
            info "Updating would overwrite them, so the update can't go ahead until they're set aside."
            if ui_confirm "Set these changes aside (git stash) and update?" y; then
                if ! out=$(git -C "$WB_HOME" stash push --include-untracked -m "set aside by waterbear update $(date '+%F %T')" 2>&1); then
                    sed 's/^/      /' <<< "$out"
                    WB_UPDATE_ERR="Waterbear wasn't updated: couldn't set aside the hand-made changes in $WB_HOME (git's message is above)."
                    return 1
                fi
                ok "Changes set aside. To get them back: git -C $WB_HOME stash pop"
            else
                WB_UPDATE_ERR="Waterbear wasn't updated: $WB_HOME has hand-made changes (listed above). Run 'waterbear update' again and say yes to setting them aside, or undo them with: git -C $WB_HOME checkout -- ."
                return 1
            fi
        fi
        if ! out=$(git -C "$WB_HOME" pull --ff-only 2>&1); then
            sed 's/^/      /' <<< "$out"
            if grep -qiE "could not resolve|unable to access|timed out|network" <<< "$out"; then
                WB_UPDATE_ERR="Waterbear wasn't updated: couldn't reach GitHub. Check your internet connection, then run 'waterbear update' again."
            elif grep -qiE "not possible to fast-forward|diverg" <<< "$out"; then
                WB_UPDATE_ERR="Waterbear wasn't updated: $WB_HOME has its own commits that aren't on GitHub (git -C $WB_HOME log). Move them to your dev copy, then: git -C $WB_HOME reset --hard origin/main"
            else
                WB_UPDATE_ERR="Waterbear wasn't updated: 'git pull' failed in $WB_HOME (git's message is above)."
            fi
            return 1
        fi
    else
        local tmp; tmp=$(mktemp -d)
        if ! out=$(git clone --depth 1 "$WB_REPO_URL" "$tmp/wb" 2>&1) || [[ ! -x "$tmp/wb/waterbear" ]]; then
            sed 's/^/      /' <<< "$out"
            rm -rf "$tmp"
            WB_UPDATE_ERR="Waterbear wasn't updated: couldn't download it from $WB_REPO_URL (message above). Kept the current version."
            return 1
        fi
        rm -rf "$WB_HOME.old"
        if ! { mv "$WB_HOME" "$WB_HOME.old" && mv "$tmp/wb" "$WB_HOME"; }; then
            [[ -d "$WB_HOME" ]] || mv "$WB_HOME.old" "$WB_HOME"
            rm -rf "$tmp"
            WB_UPDATE_ERR="Waterbear wasn't updated: couldn't replace the files in $WB_HOME. Kept the current version."
            return 1
        fi
        rm -rf "$WB_HOME.old" "$tmp"
    fi
    return 0
}

# Shows what went wrong: red box in the terminal, desktop notification, log file
update_report_failure() {
    local p
    mkdir -p "$(dirname "$WB_UPDATE_LOG")"
    {
        echo "waterbear update — $(date '+%F %T') — FAILED"
        for p in "$@"; do echo "  - $p"; done
    } > "$WB_UPDATE_LOG"
    echo
    if command -v gum > /dev/null; then
        gum style --border double --border-foreground 9 --foreground 9 --padding "0 2" --margin "0 1" --width 78 \
            "UPDATE FAILED" "" "${@/#/• }" "" "This message is saved in: $WB_UPDATE_LOG"
    else
        printf '%s xx UPDATE FAILED%s\n' "$c_red" "$c_off" >&2
        for p in "$@"; do printf '%s xx%s %s\n' "$c_red" "$c_off" "$p" >&2; done
        printf '    This message is saved in: %s\n' "$WB_UPDATE_LOG" >&2
    fi
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v notify-send > /dev/null; then
        notify-send -u critical -a Waterbear "Waterbear update failed" "$1 (details: $WB_UPDATE_LOG)" 2> /dev/null || true
    fi
}

waterbear_update() {
    need_sudo
    local problems=()
    if [[ -f /etc/snapper/configs/root ]]; then
        snapshot_now "before-update-$(date +%F)" || problems+=("Couldn't take the before-update snapshot (snapper's message is above).")
    fi
    step "Updating the system"
    sudo pacman -Syu --noconfirm || problems+=("The system update (pacman -Syu) failed. Scroll up for pacman's error.")
    if command -v yay > /dev/null; then
        step "Updating AUR apps"
        yay -Sua --noconfirm || problems+=("Some AUR updates (yay -Sua) failed. Scroll up for yay's error.")
    fi

    step "Updating Waterbear (you have $WB_VERSION)"
    local new
    if wb_self_update; then
        new="$(cat "$WB_HOME/VERSION" 2> /dev/null || echo unknown)"
        if [[ "$new" == "$WB_VERSION" ]]; then ok "Waterbear is up to date ($new)."
        else ok "Waterbear updated: $WB_VERSION → $new"; fi
    else
        problems+=("$WB_UPDATE_ERR")
    fi

    step "Refreshing configs"
    # Run the (possibly new) Waterbear to re-apply configs with the latest templates
    "$WB_HOME/waterbear" apply || problems+=("Refreshing configs ('waterbear apply') failed. Scroll up for the error.")

    if (( ${#problems[@]} )); then
        update_report_failure "${problems[@]}"
        return 1
    fi
    mkdir -p "$(dirname "$WB_UPDATE_LOG")"
    echo "waterbear update — $(date "+%F %T") — OK (version $new)" > "$WB_UPDATE_LOG"
    ok "System and Waterbear updated."
}

# ---------------------------------------------------------------------------
# Auto-update: run at every Hyprland login (`waterbear autoupdate`, started by hyprland.lua).
# Checks the VERSION file on GitHub; if it's newer than the installed one:
#   ask  → a notification with an "Update now" button (opens the full `waterbear update`)
#   auto → updates Waterbear itself quietly (no password needed), then notifies.
#          System packages need your password, so they stay with the manual Update.
# ---------------------------------------------------------------------------
version_newer() {  # version_newer A B — true if version A is newer than B
    [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}

wb_notify() {  # wb_notify URGENCY TITLE BODY [notify-send args...]
    local u="$1" t="$2" b="$3"; shift 3
    command -v notify-send > /dev/null || return 0
    notify-send -u "$u" -a Waterbear "$@" "$t" "$b" 2> /dev/null || true
}

cmd_autoupdate() {
    state_load
    [[ "$AUTO_UPDATE" == off ]] && return 0
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/waterbear"
    mkdir -p "$cache"
    exec 9> "$cache/autoupdate.lock"
    flock -n 9 || return 0   # already checking (e.g. Hyprland restarted)

    # Wait for the network after login: try for about 3 minutes, then give up until the next login
    local remote="" i
    for i in $(seq 1 18); do
        remote=$(curl -fsSL --max-time 10 "$WB_RAW_URL/VERSION" 2> /dev/null | tr -d '[:space:]') || remote=""
        [[ "$remote" =~ ^[0-9]+(\.[0-9]+)*$ ]] && break
        remote=""; sleep 10
    done
    [[ -n "$remote" ]] || return 0
    version_newer "$remote" "$WB_VERSION" || return 0

    if [[ "$AUTO_UPDATE" == auto ]]; then
        # Never set hand-made changes aside without asking: fall back to the "ask" notification
        if [[ -d "$WB_HOME/.git" && -n "$(git -C "$WB_HOME" status --porcelain 2> /dev/null)" ]]; then
            :
        else
            INTERACTIVE=false
            local problem=""
            if ! wb_self_update > /dev/null 2>&1; then problem="$WB_UPDATE_ERR"
            elif ! "$WB_HOME/waterbear" apply > /dev/null 2>&1; then problem="Downloaded $remote, but refreshing configs ('waterbear apply') failed. Run it in a terminal to see why."
            fi
            if [[ -z "$problem" ]]; then
                echo "waterbear auto-update — $(date '+%F %T') — OK ($WB_VERSION → $remote)" > "$WB_UPDATE_LOG"
                wb_notify normal "Waterbear updated to $remote" "You had $WB_VERSION. System packages: Waterbear menu → Update."
                return 0
            fi
            echo "waterbear auto-update — $(date '+%F %T') — FAILED: $problem" > "$WB_UPDATE_LOG"
            wb_notify critical "Waterbear auto-update failed" "$problem (details: $WB_UPDATE_LOG)"
            return 1
        fi
    fi

    # ask: the notification waits for a click; "Update now" opens the full update in a terminal
    local action
    action=$(notify-send -u normal -a Waterbear --wait --action=update="Update now" \
        "Waterbear $remote is available" "You have $WB_VERSION. Update now: snapshot → system update → new Waterbear." 2> /dev/null) || true
    if [[ "$action" == update ]]; then
        setsid kitty --class waterbear-menu -e bash -c \
            '"$1" update; echo; read -rsn1 -p "  press any key to close"' _ "$WB_BIN/waterbear" > /dev/null 2>&1 &
    fi
    return 0
}
