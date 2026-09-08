# Philemon

Philemon is a keyboard-first Linux file manager with a Quickshell UI and Rust backend.
It is a fork of [Flea](https://github.com/thisisgm/flea), based on v0.1.5, with changes
for EndeavourOS and other Arch-based desktops. Omarchy is not required: the package
includes QML compatibility modules and a standalone dark theme.

## Features

- List, columns and grid views, with directory tabs and a path bar.
- File search, thumbnails, and previews for text, images, PDFs, audio and video.
- Copy, move, trash, rename and undo, plus archive browsing and extraction.
- Network mounts through GVFS and local drive management, including USB and
  hot-pluggable SSDs that report non-removable media.
- Configurable context menus, text size, and Default, Vim, Mac and Windows keyboard presets.
- Optional desktop file chooser and “Show in folder” integration.

The terminal interface (`--tui`) is not implemented.

## Install

On EndeavourOS or another Arch-based system, install the build tools and Git, then
build the package from this repository:

```bash
sudo pacman -S --needed base-devel git
git clone https://github.com/jehutyw/philemon.git
cd philemon
makepkg -si
```

The package declares its runtime dependencies, including Quickshell and Qt, in
[`PKGBUILD`](PKGBUILD). Optional dependencies there enable features such as archive
support, image conversion and media metadata.

Launch from your application menu or run:

```bash
philemon
philemon ~/Downloads
```

To update, run these commands from the checkout:

```bash
git pull --ff-only
makepkg -si
```

### Desktop integration

To use Philemon as the default file manager, “Show in folder” handler and portal
file chooser:

```bash
philemon --default
systemctl --user restart xdg-desktop-portal
```

On Omarchy, this also updates its file-manager shortcuts. Other desktops keep
their existing shortcuts.

To enable only the file chooser for applications that use desktop portals:

```bash
philemon --picker
systemctl --user restart xdg-desktop-portal
```

Use `philemon --default off` or `philemon --picker off` to remove the corresponding
preferences. Removing the default does not restore a previously pinned file manager;
set that again with your desktop settings or `xdg-mime`.

## Keyboard basics

These bindings are available in the Default preset. Open settings with `Ctrl+,`
to change presets; the full binding table is in [`keys.toml`](keys.toml).

| Key | Action |
|---|---|
| Up / Down or `k` / `j` | Move the cursor |
| Backspace or `h` | Parent directory |
| Enter | Open |
| Space | Toggle Quick Look |
| Ctrl+L | Enter a path |
| Ctrl+F | Search |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / cut / paste |
| F2 | Rename |
| Delete | Move to trash |
| Ctrl+Z | Undo |
| Ctrl+Shift+N | New folder |
| `t` / `w` | Open / close a tab |
| `1`–`9` | Switch tabs |
| Ctrl+1 / Ctrl+2 / Ctrl+3 | List / columns / grid |

## Development

With the runtime dependencies installed, build and run the checkout's UI:

```bash
cargo build --release --locked
PHILEMON_UI="$PWD/ui" ./target/release/philemon
```

Run the headless test suites:

```bash
./tests/run-all.sh
```

GUI tests require a running desktop session. The backend's JSON protocol is
documented in [`docs/protocol.md`](docs/protocol.md).

The screenshots and benchmark data under `docs/` were inherited from Flea and do
not establish this fork's current appearance or performance.

## License

[MIT](LICENSE). Original project by [thisisgm](https://github.com/thisisgm/flea).
