use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

pub const LIMIT: usize = 2 * 1024 * 1024;
static NEXT: AtomicU64 = AtomicU64::new(0);

pub fn target(vault: &Path, path: &Path) -> Result<PathBuf, String> {
    let root = fs::canonicalize(vault).map_err(|_| "The vault is unavailable.")?;
    if !root.join(".obsidian").is_dir() { return Err("This is not an Obsidian vault.".into()); }
    let real = fs::canonicalize(path).map_err(|_| "That note no longer exists.")?;
    if !real.starts_with(&root) || real.strip_prefix(&root).unwrap().components().any(|c| c.as_os_str() == ".obsidian") {
        return Err("The note is outside this vault.".into());
    }
    if !real.is_file() || !real.extension().is_some_and(|e| e.eq_ignore_ascii_case("md")) {
        return Err("Only Markdown notes can be edited here.".into());
    }
    Ok(real)
}

pub fn read(path: &Path) -> Result<String, String> {
    let file = File::open(path).map_err(|_| "The note could not be read. Check permissions.")?;
    let mut bytes = Vec::new();
    file.take((LIMIT + 1) as u64).read_to_end(&mut bytes).map_err(|_| "The note could not be read.")?;
    if bytes.len() > LIMIT { return Err("This editor supports notes up to 2 MiB.".into()); }
    if bytes.contains(&0) { return Err("This note contains binary data.".into()); }
    String::from_utf8(bytes).map_err(|_| "This editor requires a UTF-8 note.".into())
}

fn encoded(original: &str, text: &str) -> String {
    let mut text = text.replace("\r\n", "\n");
    if original.contains("\r\n") && !original.replace("\r\n", "").contains('\n') {
        text = text.replace('\n', "\r\n");
    }
    if original.starts_with('\u{feff}') && !text.starts_with('\u{feff}') { text.insert(0, '\u{feff}'); }
    text
}

// Keep a durable, private copy before replacement. The backup is outside the vault and
// survives a conflict or crash; it is never part of the file manager's undo journal.
fn backup(dir: &Path, path: &Path, original: &str) -> Result<(), String> {
    fs::create_dir_all(&dir).map_err(|_| "Could not create the note backup directory.")?;
    fs::set_permissions(&dir, fs::Permissions::from_mode(0o700)).map_err(|_| "Could not protect note backups.")?;
    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_nanos();
    let name = format!("{now}-{}-{}.md", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed));
    let dest = dir.join(name);
    let mut file = OpenOptions::new().write(true).create_new(true).mode(0o600).open(&dest)
        .map_err(|_| "Could not create a backup; the note was not saved.")?;
    file.write_all(original.as_bytes()).and_then(|()| file.sync_all())
        .map_err(|_| "Could not finish the backup; the note was not saved.")?;
    // Sidecar identifies the source without changing the backup's original bytes.
    let mut info = OpenOptions::new().write(true).create_new(true).mode(0o600).open(dest.with_extension("path"))
        .map_err(|_| "Could not record the backup source.")?;
    info.write_all(path.as_os_str().as_encoded_bytes()).and_then(|()| info.sync_all())
        .map_err(|_| "Could not record the backup source.")?;
    File::open(dir).and_then(|f| f.sync_all()).map_err(|_| "Could not sync the backup directory.".into())
}

pub fn save(path: &Path, original: &str, text: &str) -> Result<String, String> {
    let state = crate::userfile::env_dir("XDG_STATE_HOME")
        .unwrap_or(crate::userfile::home()?.join(".local/state"));
    save_with_backups(path, original, text, &state.join("philemon/note-backups"))
}

pub(super) fn save_with_backups(path: &Path, original: &str, text: &str, backups: &Path) -> Result<String, String> {
    if original.len() > LIMIT || text.len() > LIMIT { return Err("This editor supports notes up to 2 MiB.".into()); }
    if read(path)? != original { return Err("Changed outside Philemon. Your edits are kept; copy them before reloading the disk version.".into()); }
    let text = encoded(original, text);
    if text.len() > LIMIT || text.contains('\0') { return Err("The edited note is too large or contains binary data.".into()); }
    if text == original { return Ok(text); }
    let meta = fs::metadata(path).map_err(|_| "The note is unavailable.")?;
    if meta.permissions().readonly() { return Err("The note is read-only.".into()); }
    if meta.nlink() != 1 { return Err("This note has hard links; edit it with an external editor.".into()); }
    backup(backups, path, original)?;
    let parent = path.parent().ok_or("The note has no parent folder.")?;
    let tmp = parent.join(format!(".philemon-note-{}-{}.tmp", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
    let mut file = OpenOptions::new().write(true).create_new(true).mode(0o600).open(&tmp)
        .map_err(|_| "The vault is not writable; the note was not saved.")?;
    let result = (|| {
        file.write_all(text.as_bytes()).and_then(|()| file.sync_all()).map_err(|_| "The note could not be written.")?;
        file.set_permissions(meta.permissions()).map_err(|_| "The note permissions could not be preserved.")?;
        // Recheck immediately before the atomic replacement; never truncate the live note.
        if read(path)? != original { return Err("Changed outside Philemon while saving. Your edits are kept.".into()); }
        fs::rename(&tmp, path).map_err(|_| "The note could not be replaced.")?;
        File::open(parent).and_then(|f| f.sync_all()).map_err(|_| "The note was written but directory sync failed; reload before retrying.")?;
        Ok(text)
    })();
    if result.is_err() { let _ = fs::remove_file(&tmp); }
    result
}
