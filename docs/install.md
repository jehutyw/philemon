# Installing Philemon

Philemon installs on Arch-based systems, including EndeavourOS. `quickshell` is the GUI runtime;
the small Commons and Ui compatibility modules Philemon uses ship with the package, so Omarchy is not
required.

Philemon installs as an Arch package, so pacman owns both ends: `makepkg -si` puts it on, `pacman -Rns`
takes it off, and pacman's own file list is what makes the second claim provable. There is no
install script here because there is nothing for one to do. The one step pacman cannot own, making
Philemon your default file manager, is a subcommand of the binary, `philemon --default`, described below.

## Build and install

```
git clone https://github.com/jehutyw/philemon.git
cd philemon
makepkg -si
```

Three lines, and the third one is the whole build: `-s` pulls in anything missing from `depends`
and `makedepends`, and `-i` hands the finished package to pacman.

`source=()` is empty on purpose, and it is worth saying why, because it is not obvious: with no
source array makepkg builds from `$startdir`, the directory the PKGBUILD sits in. So a fresh clone
is the source, and so is a checkout you are editing. `build()` reads that directory in place and
redirects `CARGO_TARGET_DIR` into makepkg's own source directory so a package build never disturbs
the tree's `target/` under a benchmark. `check()` runs `cargo test --release`, so a package that
builds is a package whose suite passed. **Build from a clean tree:** the checkout is the source, so
uncommitted edits are what gets packaged.

## What lands on disk

| Path | What it is |
|---|---|
| `/usr/bin/philemon` | the binary, backend and launcher both |
| `/usr/share/philemon/ui/` | the Quickshell UI, which `paths.rs` looks for by `shell.qml` |
| `/usr/share/philemon/ui/Commons`, `/usr/share/philemon/ui/Ui` | Philemon's bundled QML compatibility modules |
| `/usr/share/applications/com.thisisgm.philemon.desktop` | the desktop entry |
| `/usr/share/icons/hicolor/scalable/apps/com.thisisgm.philemon.svg` | the icon |
| `/usr/share/licenses/philemon/LICENSE` | the licence |

The count is whatever the built archive declares, not a number written down here: the UI grows a file
whenever a component is added, so a figure pinned in this paragraph would be stale by the next commit.
`packaging/philemon-package-test` reads the count out of the archive and fails if the fake root does not
hold exactly that many.

## Uninstall

```
sudo pacman -Rns philemon
```

Everything above goes, including the directories the install created. The package carries no
`.INSTALL` scriptlet, so nothing is ever created outside the file list pacman tracks, and the
desktop and icon caches are re-indexed by Arch's own `update-desktop-database` and
`gtk-update-icon-cache` hooks, which fire on Remove as well as on Install.

## Make Philemon the default

Installing registers Philemon for `inode/directory`; it does not make it the default. This is a
per-user preference, so pacman cannot own it, and
Omarchy's own `default` verbs (`omarchy default browser`, `editor`, `terminal`) set exactly this
kind of thing without a package's help. There is no `omarchy default filemanager`, and
`/usr/share/omarchy/` is the package's to overwrite, so Philemon carries the verb itself:

```
philemon --default
```

It sets the directory MIME handler through `xdg-mime`. On Omarchy it also updates Omarchy's two
file-manager keys; on other desktops it leaves keyboard shortcuts to the desktop's settings.
It needs no root.

1. **The `inode/directory` handler.** `xdg-mime default com.thisisgm.philemon.desktop inode/directory`,
   the stock tool, which writes one line to `~/.config/mimeapps.list`. The line printed names the
   previous handler, `org.gnome.Nautilus.desktop` on a stock Omarchy, which comes from
   `/usr/share/applications/mimeapps.list`. Only that one type: the entry registers nothing else,
   and a file manager that takes image or archive types is a bad citizen. The answer is read back
   with `xdg-mime query default` rather than trusted, because `xdg-mime default` exits 0 whatever it
   wrote.
2. **Omarchy only: its two file-manager keys.** `SUPER + SHIFT + F` and `SUPER + ALT + SHIFT + F` are bound
   to Nautilus in `/usr/share/omarchy/default/hypr/bindings/applications.lua`, which
   `omarchy update` overwrites, so the override goes where the Omarchy manual says an override
   goes: appended to `~/.config/hypr/bindings.lua`, between two marker lines, in the manual's own
   `hl.unbind` then `o.bind` shape:

   ```lua
   -- philemon --default: begin. Written by `philemon --default`; `philemon --default off` removes the block whole.
   hl.unbind("SUPER + SHIFT + F")
   o.bind("SUPER + SHIFT + F", "File manager", { launch = 'philemon --gui' })
   hl.unbind("SUPER + ALT + SHIFT + F")
   o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { launch = 'philemon --gui "$(omarchy-cmd-terminal-cwd)"' })
   -- philemon --default: end.
   ```

   The cwd key keeps its meaning: `omarchy-cmd-terminal-cwd` is the helper Omarchy's own Nautilus
   binding reads the active terminal's directory with, and Philemon's positional argument is a path.
   After writing, `hyprctl reload` runs and `hyprctl configerrors` is read; if the config no longer
   loads, the file is put back as it was and the command fails saying what `configerrors` said. The
   output names what each key ran before, read off `hyprctl binds`. From outside the session,
   where `hyprctl` cannot be reached, the block is still written and the output says to run
   `hyprctl reload` yourself.

Run it from a terminal inside the session, so the keys take effect at once.

### Undo

```
philemon --default off
```

Removes Philemon's `inode/directory` line from `~/.config/mimeapps.list`, so the handler falls back to
whatever the system default is (Nautilus on stock Omarchy), and removes the marked block from
`~/.config/hypr/bindings.lua` byte for byte, then reloads. If you had pinned another handler in
`~/.config/mimeapps.list` before running `philemon --default`, the first run printed its id as
`was <id>`; `xdg-mime default <id> inode/directory` puts that pin back.

### What `pacman -Rns philemon` leaves behind

Everything the package installed goes, as above. The two edits `philemon --default` made are per-user
state, and pacman neither knows nor should know about them, so they stay:

- `inode/directory=com.thisisgm.philemon.desktop` in `~/.config/mimeapps.list`. Inert once the binary
  is gone: `xdg-mime query default` skips an entry whose `Exec` is not on `PATH`, and answered
  `org.gnome.Nautilus.desktop` with that line in place when this was exercised without a `philemon` on
  `PATH`. Still litter. Delete the line, or run
  `xdg-mime default org.gnome.Nautilus.desktop inode/directory`.
- The block between `-- philemon --default: begin` and `-- philemon --default: end` in
  `~/.config/hypr/bindings.lua`. With no `philemon` on `PATH` the two keys would do nothing. Delete the
  block and run `hyprctl reload`.

The clean order is `philemon --default off` before `sudo pacman -Rns philemon`, after which there is nothing
to do by hand. `philemon --default off` leaves `~/.config/mimeapps.list` in place even when it was the
one that created it, holding an empty `[Default Applications]` section: the file is the desktop's,
other tools write to it too, and an empty section is harmless.

## Why the Exec line reads `philemon --gui %f`

`%f` because Philemon's positional argument is a path. A `%u` entry advertises that the program
understands URI schemes, and Philemon's positional does not: only `--select` strips a `file://` prefix
and percent-decodes. For a local directory the two field codes measure the same, both hand over one
decoded path, so the difference only shows on a remote URI, where `%u` would give Philemon an
`smb://host/share` string to treat as a relative path.

`--gui` because a desktop entry always means the window. Without it the mode is inferred from
whatever stdio the launcher hands over, and while every launcher measured here hands over none (glib
routes the launch through the session bus, so the child's stdio is the user manager's), an inference
is a worse contract than a flag.

`StartupWMClass` because the window's app id comes from the `AppId` pragma at `ui/shell.qml:1` and
is not the binary name. `packaging/philemon-package-test` reads both and fails if they drift apart.

## Proving it

```
printf '%s\n' "$OMARCHY_SUDO_PASS" | packaging/philemon-package-test
```

Builds the package, installs it into a fake root, checks the fake root holds exactly the file count
the archive declares, removes it, and checks nothing survives. Every write is inside a `mktemp -d`
the shared guard has cleared; pacman is confined by `--root` and `--dbpath`, and the one root
`rm -rf` runs on a path `sandbox_require` has just checked. Without a password on stdin the round
trip is skipped and the rest still runs.

## Known gap: Open containing folder

Applications that offer "Open containing folder" ask the `org.freedesktop.FileManager1` D-Bus
interface for `ShowItems` first. Philemon does not implement it, so those applications get whatever
fallback they carry; the common one, opening the parent directory through the `inode/directory`
handler, lands on Philemon and works. Wiring `ShowItems` to the `--select` that already exists needs a
D-Bus service in the backend, which is not part of this packaging work.
