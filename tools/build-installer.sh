#!/usr/bin/env bash
# tools/build-installer.sh — bundle the whole repo into one self-contained file: dist/Installer.sh
# (Handy for a USB stick: no internet needed to get Waterbear itself.)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist/Installer.sh"
mkdir -p "$ROOT/dist"
{
cat << 'HEADER'
#!/usr/bin/env bash
# Installer.sh — Waterbear, an Arch + Hyprland setup. https://github.com/ThomasCochran/waterbear
# One file with everything inside. Run it on Arch as your normal user:
#   chmod +x Installer.sh && ./Installer.sh            (setup wizard)
#   ./Installer.sh --yes                               (all defaults, no questions)
# Options are passed to `waterbear setup`; extract and run `./waterbear help` to see them.
set -euo pipefail
[[ $EUID -eq 0 ]] && { echo "Run this as your normal user, not root." >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
sed '1,/^__WATERBEAR_PAYLOAD__$/d' "$0" | base64 -d | tar -xz -C "$tmp"
bash "$tmp/install.sh" "$@"
exit $?
__WATERBEAR_PAYLOAD__
HEADER
tar -czf - --exclude=.git --exclude=dist --exclude=ideas.txt --exclude=PKGBUILD --exclude=src --exclude=pkg --exclude="*.pkg.tar.*" -C "$ROOT" . | base64
} > "$OUT"
chmod +x "$OUT"
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
