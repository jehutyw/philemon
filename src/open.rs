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

// xdg-open is the OEM route: omarchy default browser, editor and terminal all configure what it reads.
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

fn handoff(target: &std::ffi::OsStr) -> i32 {
    // The setting is inherited across exec, so this is the last point that can hand it back.
    thp::enable();
    // corner: spawn and not exec, because xdg-open waits for the program it starts; see AGENTS.md "Opening a file".
    let started = Command::new("xdg-open")
        .arg(target)
        // The handler outlives us, so an inherited pipe would kill it on its first write; see AGENTS.md "Opening a file".
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        // Its own process group, so nothing that later kills Philemon's group reaches the opened program.
        .process_group(0)
        .spawn();
    match started {
        Ok(_) => 0,
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
        assert_eq!(super::obsidian_uri("/vault/café # &?.md"),
            "obsidian://open?path=%2Fvault%2Fcaf%C3%A9%20%23%20%26%3F.md");
    }
}
