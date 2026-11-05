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
 "SSH (port 22) — connect to this laptop remotely::ssh"
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
# ---------------------------------------------------------------------------
waterbear_update() {
    need_sudo
    [[ -f /etc/snapper/configs/root ]] && snapshot_now "before-update-$(date +%F)"
    step "Updating the system"
    sudo pacman -Syu --noconfirm
    if command -v yay > /dev/null; then step "Updating AUR apps"; yay -Sua --noconfirm || warn "Some AUR updates failed."; fi

    step "Updating Waterbear (you have $WB_VERSION)"
    if [[ -d "$WB_HOME/.git" ]]; then
        git -C "$WB_HOME" pull --ff-only || warn "Couldn't update Waterbear (local changes? network?)."
    else
        local tmp; tmp=$(mktemp -d)
        if git clone --depth 1 "$WB_REPO_URL" "$tmp/wb" > /dev/null 2>&1 && [[ -x "$tmp/wb/waterbear" ]]; then
            rm -rf "$WB_HOME.old"; mv "$WB_HOME" "$WB_HOME.old" && mv "$tmp/wb" "$WB_HOME" && rm -rf "$WB_HOME.old"
            ok "Waterbear updated from GitHub."
        else
            warn "Couldn't get Waterbear from GitHub ($WB_REPO_URL). Kept the current version."
        fi
        rm -rf "$tmp"
    fi
    local new; new="$(cat "$WB_HOME/VERSION" 2> /dev/null || echo unknown)"
    if [[ "$new" == "$WB_VERSION" ]]; then ok "Waterbear is up to date ($new)."
    else ok "Waterbear updated: $WB_VERSION → $new"; fi
    ok "System and Waterbear updated. Refreshing configs..."
    # Run the (possibly new) Waterbear to re-apply configs with the latest templates
    exec "$WB_HOME/waterbear" apply
}
