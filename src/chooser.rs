// philemon --picker: the per-user step that routes the desktop's file chooser here, see docs/install.md.
use crate::hyprkeys;
use crate::userfile::{config_home, create_file, data_file, replace_file};
use std::fs;
use std::path::PathBuf;

// The interface Philemon's backend implements, and the only key in portals.conf that is Philemon's to write.
const IFACE: &str = "org.freedesktop.impl.portal.FileChooser";
// gtk stays behind philemon, so a box whose philemon.portal went missing still has a chooser at all.
const PREFERRED: &str = "philemon;gtk";
// What tools/philemon-portal registers as; xdg-desktop-portal names a backend by this file's stem.
const PORTAL_FILE: &str = "philemon.portal";
const GROUP: &str = "[preferred]";

// philemon --picker
// --default asks this before claiming, because a box with no philemon.portal has nothing to prefer.
pub fn backend_installed() -> bool {
    installed_portal().is_some()
}

pub fn claim() -> i32 {
    if installed_portal().is_none() {
        eprintln!(
            "philemon: {} is not installed in any portal directory, so there is no backend to prefer; install the package first",
            PORTAL_FILE
        );
        return 1;
    }
    // The floating rule is Hyprland syntax in the file Omarchy manages; every other desktop places
    // the chooser window itself, so off Omarchy this half says it left the window alone rather than
    // failing --default on a box that has no hypr/bindings.lua and never will.
    let window = if crate::defaults::is_omarchy() {
        hyprkeys::float_claim()
    } else {
        Ok("window rule: unchanged (your desktop places the chooser window)".to_string())
    };
    report(claim_chooser(), window)
}

// philemon --picker off
pub fn release() -> i32 {
    let window = if crate::defaults::is_omarchy() {
        hyprkeys::float_release()
    } else {
        Ok("window rule: unchanged (not running under Omarchy)".to_string())
    };
    report(release_chooser(), window)
}

// Each half stands on its own, so a failure in one still leaves the other's line on screen.
fn report(routing: Result<String, String>, window: Result<String, String>) -> i32 {
    let mut status = 0;
    for half in [routing, window] {
        match half {
            Ok(line) => println!("{}", line),
            Err(why) => {
                eprintln!("philemon: {}", why);
                status = 1;
            }
        }
    }
    // The portal reads its configuration once, at startup, so a live session keeps the old routing.
    println!("xdg-desktop-portal reads this at startup: systemctl --user restart xdg-desktop-portal");
    status
}

fn claim_chooser() -> Result<String, String> {
    let path = conf_path()?;
    if let Some(shadow) = shadowing_file()? {
        return Err(format!(
            "{} would never be read, because {} is desktop specific and wins inside the same directory; add {}={} to that file instead",
            path.display(),
            shadow.display(),
            IFACE,
            PREFERRED
        ));
    }
    let text = match fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            let dir = path.parent().ok_or_else(|| format!("{} has no directory", path.display()))?;
            fs::create_dir_all(dir).map_err(|e| format!("{} could not be created ({:?})", dir.display(), e.kind()))?;
            create_file(&path, &format!("{}\n{}={}\n", GROUP, IFACE, PREFERRED))?;
            return Ok(format!("{}: {}, written to {}", IFACE, PREFERRED, path.display()));
        }
        Err(e) => return Err(format!("{} could not be read ({:?})", path.display(), e.kind())),
    };
    let Some(next) = set_preferred(&text, IFACE, PREFERRED) else {
        return Ok(format!("{}: already {} in {}", IFACE, PREFERRED, path.display()));
    };
    replace_file(&path, &next)?;
    Ok(format!(
        "{}: {}, written to {}; every other interface keeps the routing it had",
        IFACE,
        PREFERRED,
        path.display()
    ))
}

fn release_chooser() -> Result<String, String> {
    let path = conf_path()?;
    let text = match fs::read_to_string(&path) {
        Ok(t) => t,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(format!("{}: nothing to undo, {} does not exist", IFACE, path.display()));
        }
        Err(e) => return Err(format!("{} could not be read ({:?})", path.display(), e.kind())),
    };
    let Some(next) = drop_preferred(&text, IFACE) else {
        return Ok(format!("{}: nothing to undo, {} does not name it", IFACE, path.display()));
    };
    // A file left holding nothing but the group heading was this command's own, so it goes with the key.
    if next.trim() == GROUP {
        fs::remove_file(&path).map_err(|e| format!("{} could not be removed ({:?})", path.display(), e.kind()))?;
        return Ok(format!("{}: Philemon's line removed, and {} held nothing else, so it is gone", IFACE, path.display()));
    }
    replace_file(&path, &next)?;
    Ok(format!("{}: Philemon's line removed from {}", IFACE, path.display()))
}

fn conf_path() -> Result<PathBuf, String> {
    Ok(config_home()?.join("xdg-desktop-portal").join("portals.conf"))
}

// Inside one directory xdg-desktop-portal reads <desktop>-portals.conf and stops, so a file for this
// desktop hides the plain one entirely. Sample input: XDG_CURRENT_DESKTOP=Hyprland gives hyprland-portals.conf.
fn shadowing_file() -> Result<Option<PathBuf>, String> {
    let dir = config_home()?.join("xdg-desktop-portal");
    let desktops = std::env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    for name in desktops.split(':').filter(|d| !d.is_empty()) {
        let candidate = dir.join(format!("{}-portals.conf", name.to_lowercase()));
        if candidate.is_file() {
            return Ok(Some(candidate));
        }
    }
    Ok(None)
}

// Proof the package landed, the same search defaults::installed_entry() makes for its own file.
// corner: xdg-desktop-portal 1.22.1 reads its own datadir too, so a session narrowing XDG_DATA_DIRS
// off /usr/share is refused here rather than claimed behind a --default that refused the same box.
fn installed_portal() -> Option<PathBuf> {
    data_file(&format!("xdg-desktop-portal/portals/{}", PORTAL_FILE))
}

// portals.conf(5) is a key file, of which only one key in one group is Philemon's:
//   [preferred]
//   default=hyprland;gtk
//   org.freedesktop.impl.portal.FileChooser=philemon;gtk
// Returns the file with `key=value` in [preferred], or None when it already says exactly that. A
// default= line is never touched: it is what every other interface still resolves through.
pub fn set_preferred(text: &str, key: &str, value: &str) -> Option<String> {
    let line = format!("{}={}\n", key, value);
    if !text.contains(GROUP) {
        let mut out = text.to_string();
        if !out.is_empty() && !out.ends_with('\n') {
            out.push('\n');
        }
        out.push_str(GROUP);
        out.push('\n');
        out.push_str(&line);
        return Some(out);
    }
    let mut out = String::with_capacity(text.len() + line.len());
    let mut in_group = false;
    let mut written = false;
    for raw in text.split_inclusive('\n') {
        let body = raw.trim_end_matches(['\n', '\r']);
        if body.trim_start().starts_with('[') {
            // Leaving the group without having found the key: it goes in at the end of the group.
            if in_group && !written {
                out.push_str(&line);
                written = true;
            }
            in_group = body.trim() == GROUP;
        } else if in_group && !written {
            if let Some(had) = body.strip_prefix(key).and_then(|rest| rest.strip_prefix('=')) {
                if had.trim() == value {
                    return None;
                }
                out.push_str(&line);
                written = true;
                continue;
            }
        }
        out.push_str(raw);
    }
    if !written {
        if !out.is_empty() && !out.ends_with('\n') {
            out.push('\n');
        }
        out.push_str(&line);
    }
    Some(out)
}

// Returns the file without `key` in [preferred], or None when that group does not name it.
pub fn drop_preferred(text: &str, key: &str) -> Option<String> {
    let mut out = String::with_capacity(text.len());
    let mut in_group = false;
    let mut changed = false;
    for raw in text.split_inclusive('\n') {
        let body = raw.trim_end_matches(['\n', '\r']);
        if body.trim_start().starts_with('[') {
            in_group = body.trim() == GROUP;
        } else if in_group && body.strip_prefix(key).and_then(|rest| rest.strip_prefix('=')).is_some() {
            changed = true;
            continue;
        }
        out.push_str(raw);
    }
    if changed {
        Some(out)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const BOX_SHAPE: &str = "[preferred]\ndefault=hyprland;gtk\n";

    #[test]
    fn set_preferred_adds_the_key_without_touching_the_default() {
        let out = set_preferred(BOX_SHAPE, IFACE, PREFERRED).expect("the file gains a line");
        assert_eq!(out, "[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=philemon;gtk\n");
    }

    #[test]
    fn set_preferred_creates_the_group_when_the_file_has_another_one() {
        let out = set_preferred("[something]\nkey=value\n", IFACE, PREFERRED).expect("the file gains a group");
        assert_eq!(out, "[something]\nkey=value\n[preferred]\norg.freedesktop.impl.portal.FileChooser=philemon;gtk\n");
    }

    #[test]
    fn set_preferred_replaces_another_backend_and_answers_none_for_its_own() {
        let held = "[preferred]\norg.freedesktop.impl.portal.FileChooser=gtk\ndefault=hyprland\n";
        let out = set_preferred(held, IFACE, PREFERRED).expect("the value changes");
        assert_eq!(out, "[preferred]\norg.freedesktop.impl.portal.FileChooser=philemon;gtk\ndefault=hyprland\n");
        assert_eq!(set_preferred(&out, IFACE, PREFERRED), None);
    }

    #[test]
    fn set_preferred_puts_the_key_inside_the_group_and_not_after_the_next_one() {
        let two = "[preferred]\ndefault=hyprland\n\n[other]\nkey=value\n";
        let out = set_preferred(two, IFACE, PREFERRED).expect("the file gains a line");
        assert_eq!(out, "[preferred]\ndefault=hyprland\n\norg.freedesktop.impl.portal.FileChooser=philemon;gtk\n[other]\nkey=value\n");
    }

    #[test]
    fn drop_preferred_removes_only_philemons_line() {
        let held = "[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=philemon;gtk\n";
        assert_eq!(drop_preferred(held, IFACE), Some("[preferred]\ndefault=hyprland;gtk\n".to_string()));
        assert_eq!(drop_preferred(BOX_SHAPE, IFACE), None);
        assert_eq!(drop_preferred("", IFACE), None);
    }

    #[test]
    fn drop_preferred_leaves_the_same_key_in_another_group_alone() {
        let elsewhere = "[other]\norg.freedesktop.impl.portal.FileChooser=gtk\n";
        assert_eq!(drop_preferred(elsewhere, IFACE), None);
    }
}
