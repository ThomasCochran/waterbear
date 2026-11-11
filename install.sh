#!/usr/bin/env bash
# install.sh — install the waterbear tool from a clone of the repo.
#   git clone https://github.com/ThomasCochran/waterbear && cd waterbear && ./install.sh
#
# This only installs Waterbear itself (plus gum, git and fzf, which its menus use) and the
# `waterbear` command. Your desktop isn't touched. Afterwards, open the menu with `waterbear`
# (or Super+Alt+Space) to install apps, or the whole Waterbear desktop from: Desktop → Install.
#
#   ./install.sh --yes                 no questions (adds the Super+Alt+Space shortcut)
#   ./install.sh --no-shortcut         don't add the shortcut
#   ./install.sh --desktop [OPTIONS]   also install the desktop right away (OPTIONS: see ./waterbear help)
set -euo pipefail
[[ $EUID -eq 0 ]] && { echo "Run this as your normal user, not root." >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Waterbear is for Arch Linux." >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/waterbear"

desktop=false; args=()
for a in "$@"; do
    case "$a" in --desktop) desktop=true ;; *) args+=("$a") ;; esac
done

echo "==> Getting Waterbear's tools (gum, git, fzf)"
sudo pacman -S --needed --noconfirm gum git fzf || sudo pacman -Syu --needed --noconfirm gum git fzf

if [[ "$SRC" != "$DEST" ]]; then
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -a "$SRC/." "$DEST/"
    rm -rf "$DEST/dist"
fi
chmod +x "$DEST/waterbear" "$DEST"/bin/* "$DEST/install.sh"

echo "==> Adding the waterbear command (/usr/local/bin/waterbear)"
sudo install -d /usr/local/bin
sudo ln -sf "$DEST/waterbear" /usr/local/bin/waterbear

shortcut_args=()
for a in "${args[@]}"; do case "$a" in --yes|-y|--no-shortcut) shortcut_args+=("$a") ;; esac; done
"$DEST/waterbear" installed "${shortcut_args[@]}"

if $desktop; then
    exec "$DEST/waterbear" setup "${args[@]}"
fi
