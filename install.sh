#!/usr/bin/env bash
# install.sh — install Waterbear from a clone of the repo.
#   git clone https://github.com/ThomasCochran/waterbear && cd waterbear && ./install.sh
# Any options are passed to `waterbear setup` (see: ./waterbear help).
set -euo pipefail
[[ $EUID -eq 0 ]] && { echo "Run this as your normal user, not root." >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Waterbear is for Arch Linux." >&2; exit 1; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/waterbear"

echo "==> Getting the installer's tools (gum, git)"
sudo pacman -Sy --needed --noconfirm gum git

if [[ "$SRC" != "$DEST" ]]; then
    rm -rf "$DEST"
    mkdir -p "$DEST"
    cp -a "$SRC/." "$DEST/"
    rm -rf "$DEST/dist"
fi
chmod +x "$DEST/waterbear" "$DEST"/bin/* "$DEST/install.sh"
exec "$DEST/waterbear" setup "$@"
