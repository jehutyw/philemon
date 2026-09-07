use crate::thp;
use std::os::unix::process::CommandExt;
use std::path::PathBuf;
use std::process::{Command, Stdio};

// The exit statuses ui/Opener.qml reads. 0 is a successful handoff and needs no name.
pub const FAILED: i32 = 2;
pub const IS_DIRECTORY: i32 = 3;

// Canonical, so a file named --output=/etc/x cannot be read as a flag by the child.
fn resolved(path: &str) -> Option<PathBuf> {
    std::fs::canonicalize(path).ok()
}

// gio open is the OEM route: it asks the desktop database, so Terminal=true is honoured; see AGENTS.md "Opening a file".
pub fn open(path: &str) -> i32 {
    let target = match resolved(path) {
        Some(p) => p,
        // The reason is elided, never shown raw, and the path is the user's own input.
        None => {
            eprintln!("philemon: that file could not be opened, check that it still exists");
            return FAILED;
        }
    };
    if target.is_dir() {
        return IS_DIRECTORY;
    }
    handoff(target.as_os_str())
}

// Obsidian registers the obsidian:// scheme, so a note in a vault opens in that vault rather than
// in whatever else claims text/markdown; see AGENTS.md "Opening a file".
pub fn obsidian(path: &str) -> i32 {
    let Some(target) = resolved(path).filter(|p| p.is_file()) else {
        eprintln!("philemon: that note could not be opened, check that it still exists");
        return FAILED;
    };
    if !target.extension().is_some_and(|e| e.eq_ignore_ascii_case("md")) {
        eprintln!("philemon: Open in Obsidian requires a Markdown note");
        return FAILED;
    }
    let Some(path) = target.to_str() else { return FAILED };
    handoff(std::ffi::OsStr::new(&obsidian_uri(path)))
}

// Percent-encoded down to the unreserved set, so a note whose name carries # or & cannot close the
// path parameter and add one of its own.
fn obsidian_uri(path: &str) -> String {
    use std::fmt::Write;
    let mut uri = String::from("obsidian://open?path=");
    for b in path.bytes() {
        if b.is_ascii_alphanumeric() || b"-._~".contains(&b) {
            uri.push(b as char);
        } else {
            write!(uri, "%{b:02X}").unwrap();
        }
    }
    uri
}

// The one launcher both routes share: a path for --open, an obsidian:// URI for --open-obsidian.
fn handoff(target: &std::ffi::OsStr) -> i32 {
    // The setting is inherited across exec, so this is the last point that can hand it back.
    thp::enable();
    // corner: waited for, not detached, and on an archive that wait is a cold handler start; see AGENTS.md "Opening a file".
    let finished = Command::new("gio")
        .arg("open")
        .arg(target)
        // The handler outlives us, so an inherited pipe would kill it on its first write; see AGENTS.md "Opening a file".
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        // Its own process group, so nothing that later kills Philemon's group reaches the opened program.
        .process_group(0)
        .status();
    match finished {
        Ok(status) if status.success() => 0,
        // A launcher that refused, which a spawn nobody waited on used to report as a clean handoff.
        Ok(_) => {
            eprintln!("philemon: gio open refused that file, so no application on this system took it");
            FAILED
        }
        Err(_) => {
            eprintln!("philemon: nothing on this system could be asked to open that file");
            FAILED
        }
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn obsidian_encodes_paths_without_uri_parameter_injection() {
        assert_eq!(
            super::obsidian_uri("/vault/café # &?.md"),
            "obsidian://open?path=%2Fvault%2Fcaf%C3%A9%20%23%20%26%3F.md"
        );
    }
}
