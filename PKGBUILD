# Maintainer: GM <gianmarcomorales@icloud.com>

pkgname=philemon
pkgver=0.1.5
pkgrel=1
pkgdesc='Fast, keyboard-first file manager for Linux desktops'
arch=('x86_64' 'aarch64')
license=('MIT')
# util-linux ships prlimit, which the thumbnail and archive sandboxes require alongside bubblewrap.
# xdg-terminal-exec is what --terminal execs, so the topbar's terminal button needs it installed.
# wl-clipboard ships wl-copy, which ui/Opener.qml pipes into for the menu's Copy Path row; nothing
# else in this closure requires it, so that row failed silently on a box without it.
# python-gobject is what tools/philemon-portal answers org.freedesktop.impl.portal.FileChooser with, and
# what tools/philemon-filemanager1 answers org.freedesktop.FileManager1 with.
# qt6-webengine ships QtQuick.Pdf and qt6-multimedia ships QtMultimedia, which ui/PreviewPdf.qml and
# ui/PreviewMedia.qml import: without them PDF and media preview cannot load at all.
# gcc-libs and glibc are the binary's only direct links, and hicolor-icon-theme owns the directory
# the desktop icon is installed into.
# python is the interpreter of two scripts this package installs and D-Bus activates at runtime, so
# it is a runtime dependency rather than only the checkdepend the sandboxed child needs.
# omarchy is upstream's dependency and not this fork's: the point of this package is a Philemon that
# runs on a plain Arch or EndeavourOS desktop, so ui/Commons and ui/Ui ship in it instead.
depends=('bubblewrap' 'expect' 'gcc-libs' 'glib2' 'glibc' 'gvfs' 'gvfs-dnssd' 'gvfs-nfs' 'gvfs-smb' 'hicolor-icon-theme' 'python' 'python-gobject' 'qt6-multimedia' 'qt6-webengine' 'quickshell' 'shared-mime-info' 'util-linux' 'wl-clipboard' 'xdg-terminal-exec' 'xdg-utils')
makedepends=('cargo')
# Both packages own /usr/bin/philemon, so pacman refuses the pair rather than leaving one half-installed.
conflicts=('philemon-git')
optdepends=('libarchive: archive listing and extraction'
            '7zip: 7z archive support'
            'imagemagick: image conversion'
            'tailscale: Taildrop sharing'
            'obsidian: open notes in registered vaults'
            'ffmpeg: media metadata in the preview column'
            'dropbox-cli: Dropbox share links')
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
  install -Dm755 tools/philemon-gio-auth "$pkgdir/usr/lib/philemon/philemon-gio-auth"
  # The portal backend, its registration and its D-Bus activation: xdg-desktop-portal 1.22 reads
  # portals/ out of every data dir, and this is Philemon's own package writing Philemon's own files.
  install -Dm755 tools/philemon-portal "$pkgdir/usr/lib/philemon/philemon-portal"
  install -Dm644 packaging/philemon.portal -t "$pkgdir/usr/share/xdg-desktop-portal/portals"
  install -Dm644 packaging/org.freedesktop.impl.portal.desktop.philemon.service -t "$pkgdir/usr/share/dbus-1/services"
  # org.freedesktop.FileManager1, which is what Chromium's "Show in folder" calls. The file is named
  # for Philemon and not for the interface: nautilus owns the plain org.freedesktop.FileManager1.service
  # path here, and dolphin, thunar and nemo each ship their own vendor-named file declaring the same
  # Name=, so a vendor name is the convention and the only way to avoid a pacman file conflict.
  install -Dm755 tools/philemon-filemanager1 "$pkgdir/usr/lib/philemon/philemon-filemanager1"
  install -Dm644 packaging/com.thisisgm.philemon.FileManager1.service -t "$pkgdir/usr/share/dbus-1/services"
  install -Dm644 packaging/com.thisisgm.philemon.desktop -t "$pkgdir/usr/share/applications"
  install -Dm644 packaging/com.thisisgm.philemon.svg -t "$pkgdir/usr/share/icons/hicolor/scalable/apps"
  install -Dm644 LICENSE -t "$pkgdir/usr/share/licenses/$pkgname"

  # paths.rs looks for /usr/share/philemon/ui/shell.qml, so the UI ships as data beside the binary.
  install -Dm644 ui/qmldir ui/*.qml -t "$pkgdir/usr/share/philemon/ui"
  install -Dm644 ui/js/*.js -t "$pkgdir/usr/share/philemon/ui/js"
  # Philemon carries the small compatibility modules it needs, so it works without Omarchy.
  cp -a ui/Commons ui/Ui "$pkgdir/usr/share/philemon/ui/"
}
