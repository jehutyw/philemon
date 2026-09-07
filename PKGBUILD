# Maintainer: GM <gianmarcomorales@icloud.com>

pkgname=philemon
pkgver=0.1.3
pkgrel=6
pkgdesc='Fast, keyboard-first file manager for Linux desktops'
arch=('x86_64')
license=('MIT')
# util-linux ships prlimit, which the thumbnail and archive sandboxes require alongside bubblewrap.
depends=('bubblewrap' 'glib2' 'quickshell' 'shared-mime-info' 'util-linux' 'xdg-utils')
makedepends=('cargo')
optdepends=('libarchive: archive listing and extraction'
            '7zip: 7z archive support'
            'imagemagick: image conversion'
            'tailscale: Taildrop sharing'
            'obsidian: open notes in registered vaults')
# The release profile strips, so a debug package would have nothing to hold.
options=('!debug')
# Empty on purpose: with no source array makepkg builds from $startdir, so a clone is the source.
source=()

build() {
  # Its own target directory, so a makepkg run never disturbs the checkout's target/.
  export CARGO_TARGET_DIR="$srcdir/target"
  cd "$startdir"
  cargo build --release --locked
}

check() {
  export CARGO_TARGET_DIR="$srcdir/target"
  cd "$startdir"
  cargo test --release --locked
  # These two need no built binary and locate themselves, so they run correctly under makepkg.
  # The rest of tests/ resolves ./target/<profile>/philemon against the repo root, which CARGO_TARGET_DIR
  # has moved, so they would refuse on a clean clone or silently test a stale binary on a dev box.
  ./tests/js.sh
  ./tests/keymap-gen.sh
}

package() {
  cd "$startdir"
  install -Dm755 "$srcdir/target/release/philemon" "$pkgdir/usr/bin/philemon"
  install -Dm644 packaging/com.thisisgm.philemon.desktop -t "$pkgdir/usr/share/applications"
  install -Dm644 packaging/com.thisisgm.philemon.svg -t "$pkgdir/usr/share/icons/hicolor/scalable/apps"
  install -Dm644 LICENSE -t "$pkgdir/usr/share/licenses/$pkgname"

  # paths.rs looks for /usr/share/philemon/ui/shell.qml, so the UI ships as data beside the binary.
  install -Dm644 ui/qmldir ui/*.qml -t "$pkgdir/usr/share/philemon/ui"
  install -Dm644 ui/js/*.js -t "$pkgdir/usr/share/philemon/ui/js"
  # Philemon carries the small compatibility modules it needs, so it works without Omarchy.
  cp -a ui/Commons ui/Ui "$pkgdir/usr/share/philemon/ui/"
}
