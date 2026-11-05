# Maintainer: Thomas Cochran <https://github.com/ThomasCochran>
#
# Local package for Waterbear. Build and install it from this folder with:
#   makepkg -si
# Then run `waterbear setup` as your normal user to set up the desktop.

pkgname=waterbear
pkgver=1.0.2   # keep the same as the VERSION file
pkgrel=1
pkgdesc="An Arch + Hyprland setup: themed, keyboard-driven desktop with switchable color schemes and snapshots"
arch=('any')
url="https://github.com/ThomasCochran/waterbear"
license=('MIT')
depends=('bash' 'git' 'gum' 'sudo')
optdepends=(
    'hyprland: the desktop Waterbear sets up (installed by `waterbear setup`)'
    'yay: AUR apps such as LocalSend'
    'snapper: btrfs snapshots (installed by `waterbear setup`)'
)
# Built from the files in this folder, nothing is downloaded.
source=()

package() {
    local dest="$pkgdir/usr/share/$pkgname"
    install -dm755 "$dest"

    # Copy the project, minus git data, build output and private notes
    tar -C "$startdir" -cf - \
        --exclude=.git --exclude=.gitignore --exclude=dist \
        --exclude=src --exclude=pkg --exclude='*.pkg.tar.*' \
        --exclude=PKGBUILD --exclude=ideas.txt \
        . | tar -C "$dest" -xf -

    chmod 755 "$dest/waterbear" "$dest/install.sh" "$dest"/bin/*

    # `waterbear` command on the PATH (it finds its files through the symlink)
    install -dm755 "$pkgdir/usr/bin"
    ln -s "/usr/share/$pkgname/waterbear" "$pkgdir/usr/bin/waterbear"
}
