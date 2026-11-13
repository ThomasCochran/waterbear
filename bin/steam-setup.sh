#!/usr/bin/env bash
# steam-setup.sh — install Steam with the right graphics drivers.
#
#   ./steam-setup.sh          asks before installing the NVIDIA driver
#   ./steam-setup.sh --yes    no questions (installs the NVIDIA driver if the card supports it)
#   ./steam-setup.sh --drivers-only [--yes]   only steps 1-4 + GameMode/MangoHud (for Lutris, Heroic…)
#
# What it does:
#   1. Turns on Arch's 32-bit "multilib" repo (Steam needs it)
#   2. Detects your GPUs (Intel / AMD / NVIDIA, including hybrid laptops)
#   3. Installs the matching 64- and 32-bit Vulkan drivers
#   4. NVIDIA (Turing / RTX 20 / Quadro T-series and newer): installs nvidia-open, sets up early
#      loading and suspend support. On hybrid laptops it adds "Steam (NVIDIA)" to the launcher,
#      which runs Steam and its games on the NVIDIA card via prime-run.
#   5. Installs Steam, GameMode and MangoHud, and downloads the latest Proton-GE
# Takes a Snapper snapshot first if Snapper is set up, so you can roll back.
set -euo pipefail

ASSUME_YES=false; DRIVERS_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --yes|-y) ASSUME_YES=true ;;
        --drivers-only) DRIVERS_ONLY=true ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg (try --help)" >&2; exit 1 ;;
    esac
done

c_cyan=$'\033[1;36m'; c_yel=$'\033[1;33m'; c_red=$'\033[1;31m'; c_grn=$'\033[1;32m'; c_off=$'\033[0m'
say()  { printf '\n%s==>%s %s\n' "$c_cyan" "$c_off" "$1"; }
ok()   { printf '%s ok%s %s\n' "$c_grn" "$c_off" "$1"; }
warn() { printf '%s !!%s %s\n' "$c_yel" "$c_off" "$1"; }
die()  { printf '%s xx%s %s\n' "$c_red" "$c_off" "$1" >&2; exit 1; }
ask_yn() {
    local q="$1" def="$2" ans
    if $ASSUME_YES; then [[ "$def" == y ]]; return; fi
    local hint="[Y/n]"; [[ "$def" == n ]] && hint="[y/N]"
    read -rp "$q $hint " ans
    ans="${ans:-$def}"
    [[ "${ans,,}" == y* ]]
}

[[ $EUID -eq 0 ]] && die "Run this as your normal user (it uses sudo when needed)."
[[ -f /etc/arch-release ]] || die "This script is for Arch Linux."
sudo -v

# ---------------------------------------------------------------------------
say "Enabling the multilib (32-bit) repo"
if grep -q '^\[multilib\]' /etc/pacman.conf; then
    ok "Already enabled."
else
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    grep -q '^\[multilib\]' /etc/pacman.conf \
        || die "Couldn't enable multilib. Uncomment [multilib] and its Include line in /etc/pacman.conf by hand."
    ok "Enabled."
fi
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm pciutils jq curl

# ---------------------------------------------------------------------------
say "Detecting graphics"
gpus="$(lspci -nn -d ::03xx)"
echo "$gpus" | sed 's/^/   /'
has_intel=false; has_amd=false; has_nvidia=false
grep -qi 'intel'          <<< "$gpus" && has_intel=true
grep -qiE 'amd|ati\b'     <<< "$gpus" && has_amd=true
grep -qi 'nvidia'         <<< "$gpus" && has_nvidia=true
hybrid=false
if $has_nvidia && { $has_intel || $has_amd; }; then hybrid=true; fi

DRIVERS=()
$has_intel && DRIVERS+=(vulkan-intel lib32-vulkan-intel intel-media-driver)
$has_amd   && DRIVERS+=(vulkan-radeon lib32-vulkan-radeon)

nvidia_installed=false
if $has_nvidia; then
    nv_line="$(grep -i nvidia <<< "$gpus" | head -1)"
    # Turing (TU1xx) and newer are supported by the open kernel modules in the official repos
    if grep -qE '\b(TU1|GA1|AD1|GB1|GB2)[0-9]{2}' <<< "$nv_line"; then
        if grep -qE '\bTU1[0-9]{2}' <<< "$nv_line" && $hybrid; then
            warn "Turing laptop GPU: with NVIDIA's current open driver the card can't fully power off,"
            warn "so battery life is shorter than without the driver (plugged-in gaming is fine)."
        fi
        if grep -qE '\bGA1[0-9]{2}' <<< "$nv_line" && $hybrid; then
            warn "Ampere laptop GPU: a few of these crash with the open driver. If that happens,"
            warn "roll back to the snapshot this script takes and ask for the proprietary-driver route."
        fi
        if ask_yn "Install the NVIDIA driver (nvidia-open)?" y; then
            # Pick the kernel-module package that matches the installed kernel(s)
            mapfile -t kernels < <(pacman -Qq linux linux-lts linux-zen linux-hardened 2>/dev/null || true)
            if [[ "${kernels[*]}" == "linux" ]]; then
                DRIVERS+=(nvidia-open)
            elif [[ "${kernels[*]}" == "linux-lts" ]]; then
                DRIVERS+=(nvidia-open-lts)
            else
                DRIVERS+=(nvidia-open-dkms)
                for k in "${kernels[@]}"; do DRIVERS+=("$k-headers"); done
            fi
            DRIVERS+=(nvidia-utils lib32-nvidia-utils egl-wayland libva-nvidia-driver)
            $hybrid && DRIVERS+=(nvidia-prime)
            nvidia_installed=true
        fi
    else
        warn "Your NVIDIA card is older than Turing (pre-RTX 20 / GTX 16)."
        warn "Its driver (nvidia-580xx-dkms or older) is only in the AUR, so this script skips it."
        if $hybrid; then
            warn "Steam will use your other GPU instead."
        else
            warn "Steam will use the open-source nouveau driver (slower for games)."
            DRIVERS+=(vulkan-nouveau lib32-vulkan-nouveau)
        fi
    fi
fi
[[ ${#DRIVERS[@]} -eq 0 ]] && warn "No known GPU driver to add. Games still install."

# ---------------------------------------------------------------------------
if [[ -f /etc/snapper/configs/root ]] && command -v snapper > /dev/null; then
    say "Taking a snapshot first"
    snap="before-$($DRIVERS_ONLY && echo gpu-drivers || echo steam)-$(date +%F)"
    sudo snapper -c root create -d "$snap" && ok "Snapshot '$snap' created."
fi

if [[ ${#DRIVERS[@]} -gt 0 ]]; then
    say "Installing graphics drivers"
    # Drivers go in first so Steam's 32-bit Vulkan dependency is already satisfied
    sudo pacman -S --needed --noconfirm "${DRIVERS[@]}"
fi

if ! $DRIVERS_ONLY; then
    say "Installing Steam"
    sudo pacman -S --needed --noconfirm steam ttf-liberation
    ok "Steam installed."
fi

say "Gaming extras: GameMode + MangoHud"
sudo pacman -S --needed --noconfirm gamemode lib32-gamemode mangohud lib32-mangohud
sudo usermod -aG gamemode "$USER"
ok "GameMode (performance boost) and MangoHud (FPS overlay) installed."

if ! $DRIVERS_ONLY; then   # Proton-GE is a Steam tool
say "Downloading the latest Proton-GE"
ge_dir="$HOME/.local/share/Steam/compatibilitytools.d"
mkdir -p "$ge_dir"
release=$(curl -fsSL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest 2>/dev/null || true)
ge_url=$(jq -r '.assets[]? | select(.name | endswith(".tar.gz")) | .browser_download_url' <<< "$release" 2>/dev/null | head -1)
sum_url=$(jq -r '.assets[]? | select(.name | endswith(".sha512sum")) | .browser_download_url' <<< "$release" 2>/dev/null | head -1)
ge_name=$(jq -r '.tag_name // empty' <<< "$release" 2>/dev/null)
if [[ -z "$ge_url" || -z "$ge_name" ]]; then
    warn "Couldn't reach GitHub for Proton-GE. Steam's own Proton still works; try again later with: steam-setup.sh"
elif [[ -d "$ge_dir/$ge_name" ]]; then
    ok "$ge_name is already installed."
else
    tmp=$(mktemp -d)
    curl -fL --progress-bar -o "$tmp/$ge_name.tar.gz" "$ge_url"
    if [[ -n "$sum_url" ]] && curl -fsSL -o "$tmp/sum" "$sum_url"; then
        want=$(awk '{print $1}' "$tmp/sum"); got=$(sha512sum "$tmp/$ge_name.tar.gz" | awk '{print $1}')
        [[ "$want" == "$got" ]] || { rm -rf "$tmp"; die "Proton-GE download didn't match its checksum. Not installed."; }
    fi
    tar -xzf "$tmp/$ge_name.tar.gz" -C "$ge_dir"
    rm -rf "$tmp"
    ok "$ge_name installed. Pick it per game: Properties → Compatibility."
fi
fi

# ---------------------------------------------------------------------------
if $nvidia_installed; then
    say "Configuring the NVIDIA driver"
    # Keep nouveau out of early boot (Arch wiki recommendation), then rebuild the initramfs
    if grep -qE '^HOOKS=.*\bkms\b' /etc/mkinitcpio.conf; then
        sudo sed -i -E '/^HOOKS=/ s/ ?\bkms\b//' /etc/mkinitcpio.conf
        echo "   Removed the kms hook from /etc/mkinitcpio.conf"
    fi
    sudo mkinitcpio -P
    # Suspend/resume support for NVIDIA (harmless if already enabled)
    sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true

    if $hybrid && ! $DRIVERS_ONLY; then
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/steam-nvidia.desktop" << 'EOF'
[Desktop Entry]
Name=Steam (NVIDIA)
Comment=Steam and its games on the NVIDIA GPU
Exec=prime-run steam %U
Icon=steam
Terminal=false
Type=Application
Categories=Network;FileTransfer;Game;
EOF
        ok "Added 'Steam (NVIDIA)' to the app launcher (Super+D)."
    fi
fi

# ---------------------------------------------------------------------------
say "Done"
if $DRIVERS_ONLY; then
    $nvidia_installed && echo "   Reboot before gaming so the NVIDIA driver loads:  reboot"
    $hybrid && $nvidia_installed && echo "   Run games on the NVIDIA card with: prime-run (Lutris/Heroic: add it as a launch prefix)"
    exit 0
fi
if $nvidia_installed; then
    echo "   Reboot before gaming so the NVIDIA driver loads:  reboot"
    echo "   After reboot, check it with:  nvidia-smi"
    if $hybrid; then
        echo "   Launch 'Steam (NVIDIA)' from Super+D so games use the NVIDIA card."
        echo "   (Or per game in plain Steam: Properties → Launch Options → prime-run %command%)"
    fi
else
    echo "   Launch Steam from Super+D or by typing: steam"
fi
echo "   One-time step in Steam: Settings → Compatibility → turn on"
echo "   'Enable Steam Play for all other titles' so Windows games run (Proton)."
echo "   FPS overlay: Launch Options → mangohud %command%   ·   Boost: gamemoderun %command%"
