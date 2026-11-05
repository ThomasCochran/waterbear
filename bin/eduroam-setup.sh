#!/usr/bin/env bash
# eduroam-setup.sh — connect to eduroam (campus Wi-Fi) with NetworkManager.
#
#   ./eduroam-setup.sh            set up (or redo) eduroam: asks for your username and password
#   ./eduroam-setup.sh --status   show whether you're connected
#   ./eduroam-setup.sh --remove   delete the saved eduroam connection
#
# Uses the usual eduroam settings (WPA2-Enterprise, PEAP + MSCHAPv2). The password is saved
# root-only in /etc/NetworkManager/system-connections, so it reconnects by itself on campus.
# If your school needs something different, use its official installer from cat.eduroam.org.
set -euo pipefail

DEFAULT_DOMAIN="umn.edu"   # added when you type just your x500
CON="eduroam"

c_cyan=$'\033[1;36m'; c_yel=$'\033[1;33m'; c_red=$'\033[1;31m'; c_grn=$'\033[1;32m'; c_off=$'\033[0m'
say()  { printf '%s==>%s %s\n' "$c_cyan" "$c_off" "$1"; }
ok()   { printf '%s ok%s %s\n' "$c_grn" "$c_off" "$1"; }
warn() { printf '%s !!%s %s\n' "$c_yel" "$c_off" "$1"; }
die()  { printf '%s xx%s %s\n' "$c_red" "$c_off" "$1" >&2; exit 1; }

cat_help() {
    cat << EOF

  If it still won't connect, use your school's official Linux installer:
    1. Get online another way (phone hotspot or the campus guest network)
    2. Go to https://cat.eduroam.org and search for your school
    3. Download the Linux installer, then run:
         sudo pacman -S --needed python python-dbus
         python3 eduroam-linux-*.py
    4. Still stuck? Your school's IT help desk has the exact settings.
EOF
}

[[ $EUID -eq 0 ]] && die "Run this as your normal user (it uses sudo when needed)."
command -v nmcli > /dev/null || die "NetworkManager isn't installed (no nmcli)."
systemctl is-active --quiet NetworkManager || die "NetworkManager isn't running: sudo systemctl enable --now NetworkManager"

case "${1:-}" in
    --status)
        if nmcli -t -f NAME connection show --active | grep -qx "$CON"; then
            ok "Connected to eduroam."
        elif nmcli -t -f NAME connection show | grep -qx "$CON"; then
            warn "eduroam is saved but not connected right now."
        else
            warn "eduroam isn't set up. Run: $0"
        fi
        exit 0 ;;
    --remove)
        sudo nmcli connection delete "$CON" && ok "Removed eduroam."
        exit 0 ;;
    -h|--help)
        sed -n '2,10p' "$0"; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1 (try --help)" ;;
esac

wifi_dev=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
[[ -n "$wifi_dev" ]] || die "No Wi-Fi card found."
nmcli radio wifi on > /dev/null 2>&1 || true

say "eduroam setup (Wi-Fi card: $wifi_dev)"
read -rp "  Username (your x500, or x500@school.edu): " user
[[ -n "$user" ]] || die "Username can't be empty."
[[ "$user" == *@* ]] || user="$user@$DEFAULT_DOMAIN"
read -rsp "  Password: " pass; echo
[[ -n "$pass" ]] || die "Password can't be empty."
domain="${user#*@}"

say "Saving the connection for $user"
sudo nmcli connection delete "$CON" > /dev/null 2>&1 || true
sudo nmcli connection add type wifi con-name "$CON" ifname "$wifi_dev" ssid eduroam \
    wifi-sec.key-mgmt wpa-eap \
    802-1x.eap peap \
    802-1x.phase2-auth mschapv2 \
    802-1x.identity "$user" \
    802-1x.anonymous-identity "anonymous@$domain" \
    802-1x.password "$pass" \
    802-1x.password-flags 0 \
    connection.autoconnect yes > /dev/null
unset pass
ok "Saved. It will connect by itself whenever eduroam is in range."

say "Looking for eduroam"
nmcli device wifi rescan > /dev/null 2>&1 || true
sleep 3
if ! nmcli -t -f SSID device wifi list | grep -qx eduroam; then
    warn "eduroam isn't in range right now. It will connect automatically on campus."
    exit 0
fi

say "Connecting"
if sudo nmcli --wait 30 connection up "$CON" > /dev/null 2>&1; then
    ok "Connected to eduroam."
    exit 0
fi

# Some schools want the anonymous identity left blank; try that once.
warn "First try failed. Retrying with a blank anonymous identity..."
sudo nmcli connection modify "$CON" 802-1x.anonymous-identity ""
if sudo nmcli --wait 30 connection up "$CON" > /dev/null 2>&1; then
    ok "Connected to eduroam."
    exit 0
fi

warn "Couldn't connect. Check your username and password, then run this again."
echo "  Details: journalctl -u NetworkManager -n 30 --no-pager"
cat_help
exit 1
