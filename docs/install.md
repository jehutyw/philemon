# Installing Philemon

Philemon installs on Arch-based systems, including EndeavourOS. `quickshell` is the GUI runtime;
the small Commons and Ui compatibility modules Philemon uses ship with the package, so Omarchy is not
required.

Philemon installs as an Arch package, so pacman owns both ends: `makepkg -si` puts it on, `pacman -Rns`
takes it off, and pacman's own file list is what makes the second claim provable. There is no
install script here because there is nothing for one to do. The steps pacman cannot own are
per-user preferences, and they are subcommands of the binary: `philemon --default` makes Philemon your
default file manager, puts it in front of the other file managers for "Show in folder", and routes
the desktop's file chooser to it, and `philemon --picker` does that last part alone. Both are described
below.

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
| `/usr/share/philemon/ui/Commons`, `/usr/share/philemon/ui/Ui` | Philemon's bundled QML compatibility modules, reached from QML as `qs.Commons` |
| `/usr/lib/philemon/philemon-portal` | the XDG portal backend, which answers `org.freedesktop.impl.portal.FileChooser` |
| `/usr/lib/philemon/philemon-filemanager1` | the D-Bus service, which answers `org.freedesktop.FileManager1` for "Show in folder" |
| `/usr/share/dbus-1/services/com.thisisgm.philemon.FileManager1.service` | what D-Bus activates that with |
| `/usr/share/xdg-desktop-portal/portals/philemon.portal` | what registers that backend with xdg-desktop-portal |
| `/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.philemon.service` | what D-Bus activates it with |
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

Installing registers Philemon for `inode/directory` and for `org.freedesktop.FileManager1`; it makes
Philemon the answer for neither, because another file manager is registered for both, and it touches no
desktop's keyboard shortcuts. All of those are per-user preferences, so pacman cannot own them, and
Omarchy's own `default` verbs (`omarchy default browser`, `editor`, `terminal`) set exactly this
kind of thing without a package's help. There is no `omarchy default filemanager`, and
`/usr/share/omarchy/` is the package's to overwrite, so Philemon carries the verb itself:

```
philemon --default
```

It does every step below, each reported on its own line, and it is honest about state: run it twice
and the second run says every step it ran is already Philemon's and rewrites nothing. It needs no root,
because every file it writes is yours, and it takes no argument, because there is one program to
name and it is Philemon. The files it writes are `~/.config/mimeapps.list`,
`~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service` and
`~/.config/xdg-desktop-portal/portals.conf`, plus `~/.config/hypr/bindings.lua` on Omarchy alone.

1. **The `inode/directory` handler.** `xdg-mime default com.thisisgm.philemon.desktop inode/directory`,
   the stock tool, which writes one line to `~/.config/mimeapps.list`. The line printed names the
   previous handler, `org.gnome.Nautilus.desktop` on a stock Omarchy, which comes from
   `/usr/share/applications/mimeapps.list`. Only that one type: the entry registers nothing else,
   and a file manager that takes image or archive types is a bad citizen. The answer is read back
   with `xdg-mime query default` rather than trusted, because `xdg-mime default` exits 0 whatever it
   wrote.
2. **"Show in folder".** Chromium, Firefox, Steam and everything else that reveals a downloaded
   file call `org.freedesktop.FileManager1` on the session bus. Installing Philemon registers for that
   name in `/usr/share/dbus-1/services`, but so do nautilus, dolphin, thunar and nemo, each in a
   file of its own in that same directory, and D-Bus keeps whichever registration it reads first.
   Any desktop that ships a file manager already has a second claimant, and which one wins inside a
   directory is the bus's business: dbus-broker sorts it, dbus-daemon takes it in readdir order, and
   neither can be steered by installing a package. So this step writes one more registration, in the
   directory that is read before every system one:

   ```
   ~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service
   ```

   ```
   # Written by `philemon --default`; `philemon --default off` removes it.
   [D-BUS Service]
   Name=org.freedesktop.FileManager1
   Exec=/usr/lib/philemon/philemon-filemanager1
   ```

   The first line is there because a user-level service file with no provenance is a bug nobody can
   trace; `dbus-broker` and `dbus-daemon` both accept it, measured on this box. The `Exec` is copied
   out of the registration the package installed rather than written down by the command, so a box
   with no `com.thisisgm.philemon.FileManager1.service` installed has nothing to put in front and this
   step refuses instead of naming a path that is not there.

3. **Omarchy only: its two file-manager keys.** This step runs where Omarchy's own directory or its
   `~/.config/hypr/bindings.lua` is present, and reports the keys unchanged everywhere else, because
   KDE Plasma, GNOME and the rest own their shortcuts through their own settings.
   `SUPER + SHIFT + F` and `SUPER + ALT + SHIFT + F` are bound
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

4. **The file chooser.** Everything `philemon --picker` does, described in the next section. A box
   updating from 0.1.3 has a Philemon with no chooser routing, and one command should finish the job.

   **This step is the skipped-not-failed one, and no other step is.** It needs
   `philemon.portal`, which only the package installs. Run a binary you built with `cargo build` on a
   box whose installed package predates the chooser, which is every box updating from 0.1.3, and
   the command prints `philemon: no portal backend is installed, so the file chooser step was skipped`
   and carries on. On such a box the honest-about-state line above is a claim about the steps that
   ran alone: the chooser was never claimed, so a second run cannot say it is already Philemon's. That
   box has no packaged `com.thisisgm.philemon.FileManager1.service` either, and step 2 says so and fails
   rather than skipping, so the command exits 1 having done steps 1 and 3. With no Philemon package
   installed at all, step 1 refuses first and nothing is written, because
   `com.thisisgm.philemon.desktop` is the proof the package landed.

Run it from a terminal inside the session, so the keys take effect at once.

### Undo

```
philemon --default off
```

Removes Philemon's `inode/directory` line from `~/.config/mimeapps.list`, so the handler falls back to
whatever the system default is (Nautilus on stock Omarchy), deletes
`~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service` and the two directories it
created when nothing else is in them, so "Show in folder" goes back to whichever packaged
registration D-Bus reads first, and removes the marked block from
`~/.config/hypr/bindings.lua` byte for byte, then reloads, and undoes the file-chooser step exactly
as `philemon --picker off` does. If you had pinned another handler in
`~/.config/mimeapps.list` before running `philemon --default`, the first run printed its id as
`was <id>`; `xdg-mime default <id> inode/directory` puts that pin back.

### What `pacman -Rns philemon` leaves behind

Everything the package installed goes, as above. The edits `philemon --default` made are per-user state,
and pacman neither knows nor should know about them, so they stay. Its chooser edits are covered by
the next section:

- `inode/directory=com.thisisgm.philemon.desktop` in `~/.config/mimeapps.list`. Inert once the binary
  is gone: `xdg-mime query default` skips an entry whose `Exec` is not on `PATH`, and answered
  `org.gnome.Nautilus.desktop` with that line in place when this was exercised without a `philemon` on
  `PATH`. Still litter. Delete the line, or run
  `xdg-mime default org.gnome.Nautilus.desktop inode/directory`.
- The block between `-- philemon --default: begin` and `-- philemon --default: end` in
  `~/.config/hypr/bindings.lua`. With no `philemon` on `PATH` the two keys would do nothing. Delete the
  block and run `hyprctl reload`.
- `~/.local/share/dbus-1/services/org.freedesktop.FileManager1.service`. This one is not inert, and
  it is the reason to run the undo before the removal: it still names
  `/usr/lib/philemon/philemon-filemanager1`, which pacman has taken away, and D-Bus does not fall through to
  the next claimant when the first one will not start. Measured here with the file in place and no
  such binary, the call answers
  `org.freedesktop.DBus.Error.Spawn.ExecFailed: Failed to execute program`, and the packaged
  registration behind it never runs. Its first line says it was written by `philemon --default`; delete
  it, or run `philemon --default off` while the binary is still there.

The clean order is `philemon --default off` before `sudo pacman -Rns philemon`, after which there is nothing
to do by hand. `philemon --default off` leaves `~/.config/mimeapps.list` in place even when it was the
one that created it, holding an empty `[Default Applications]` section: the file is the desktop's,
other tools write to it too, and an empty section is harmless.

## Make Philemon the file chooser

Every application that asks the desktop to pick a file, from `omarchy tailscale send` to a Flatpak,
goes through the XDG portal: it calls `org.freedesktop.portal.FileChooser`, and xdg-desktop-portal
hands that to whichever backend the configuration prefers. On a stock Omarchy box that is
xdg-desktop-portal-gtk, which is why a GTK dialog appears in the middle of Omarchy. Installing Philemon
registers a backend; it does not prefer it. That is a per-user preference, so:

```
philemon --picker
```

writes one key to `~/.config/xdg-desktop-portal/portals.conf`:

```
[preferred]
org.freedesktop.impl.portal.FileChooser=philemon;gtk
```

and it writes one more thing, an additive block in `~/.config/hypr/bindings.lua` beside the one
`philemon --default` writes:

```lua
-- philemon --picker: begin. Written by `philemon --picker`; `philemon --picker off` removes the block whole.
o.window("com.thisisgm.philemon.picker", { tag = "+floating-window" })
-- philemon --picker: end.
```

That is Omarchy's own treatment for a prompt, not a size Philemon invented:
`/usr/share/omarchy/default/hypr/apps/system.lua` tags `xdg-desktop-portal-gtk`'s windows the same
way, and Omarchy's tag rules are what then float, centre and size them. The picker carries its own
app id, `com.thisisgm.philemon.picker`, so this rule reaches the chooser and never the file manager
window. As with the keys, the file is written, `hyprctl reload` runs, `hyprctl configerrors` is read,
and a config that no longer loads is put back as it was.

**It writes no `default=` line**, and that is the whole design. xdg-desktop-portal
collects every configuration file it can find into an ordered list, the user's first, and resolves each
interface through them in turn: an interface this file does not name falls through to the next file,
which on Omarchy is `/usr/share/xdg-desktop-portal/hyprland-portals.conf` and its `default=hyprland;gtk`.
So ScreenCast, Screenshot, GlobalShortcuts and InputCapture still resolve to hyprland, and Account,
Email and DynamicLauncher still resolve to gtk, exactly as before. `gtk` stays behind `philemon` on Philemon's
own line for the same reason: if `philemon.portal` ever goes missing, there is still a chooser.

xdg-desktop-portal reads its configuration once, at startup, so a live session keeps the old routing
until it is restarted, which the command's second line says:

```
systemctl --user restart xdg-desktop-portal
```

The picker that then opens is Philemon: the same rows, icons, theme and keys as the window, with a check
box in front of every row a caller can receive. Space marks, Enter walks into a directory or submits
what is marked, Backspace climbs, Escape refuses. Nothing marked and Enter does nothing, because a
chooser that sends on a stray keypress is worse than one that asks twice.

### Undo

```
philemon --picker off
```

removes that one key, and removes the file too when the key was all it held, and removes the
Hyprland block byte for byte. Restart xdg-desktop-portal again and the GTK chooser is back.

### What `pacman -Rns philemon` leaves behind

`~/.config/xdg-desktop-portal/portals.conf` is per-user state like `mimeapps.list` above, so it stays.
With no `philemon.portal` installed, xdg-desktop-portal logs that the requested backend does not exist and
takes the next name on the line, which is `gtk`, so the desktop keeps a working chooser either way.
The clean order is `philemon --picker off` before `sudo pacman -Rns philemon`.

## Why the Exec line reads `philemon --gui %f`

`%f` because Philemon's positional argument is a path. A `%u` entry advertises that the program
understands URI schemes, and Philemon's positional does not: only `--select` strips a `file://` prefix
and percent-decodes. For a local directory the two field codes measure the same, both hand over one
decoded path, so the difference only shows on a remote URI, where `%u` would give Philemon an
`smb://host/share` string to treat as a relative path.

`--gui` because a desktop entry should name the mode it means, not because the launch would
otherwise land somewhere else. Bare `philemon` opens the window too, and reads no stdio to decide it, so
the flag changes nothing today: it is the contract that keeps this entry correct if bare ever stops
meaning the window. Launcher stdio is beside the point either way, and every launcher measured here
hands over none: glib routes the launch through the session bus, so the child's stdio is the user
manager's.

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

## Which file manager answers "Show in folder"

Ask the box, and it names the file it is reading the answer out of:

```bash
journalctl --user -b | grep "duplicate name 'org.freedesktop.FileManager1'"
```

Every line names a registration D-Bus threw away, so the one claimant that is not on that list is
the one answering. Run `philemon --default` and Philemon's own file is the one that is not on it, because
`$XDG_DATA_HOME` is read before `/usr/share`; run `philemon --default off` and it goes back to whichever
packaged registration is read first. Removing the file manager you are not using works too, and is
the only thing that changes the answer for a user who never runs `philemon --default`.
