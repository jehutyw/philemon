use super::store;
use std::fs;
use std::path::{Path, PathBuf};

pub fn resolve(vault: &Path, from: &Path, link: &str) -> Result<PathBuf, String> {
    let from = store::target(vault, from)?;
    let root = fs::canonicalize(vault).map_err(|_| "The vault is unavailable.")?;
    let raw = link.split('#').next().unwrap_or("");
    let raw = crate::paths::percent_decode(raw);
    if raw.is_empty() { return Ok(from); }
    if raw.contains(':') || raw.contains('?') || raw.starts_with("//") {
        return Err("Only links to notes inside this vault are supported here.".into());
    }
    let mut name = PathBuf::from(raw.trim_start_matches('/'));
    if name.extension().is_none() { name.set_extension("md"); }
    let direct = if raw.starts_with('/') { root.join(&name) } else { from.parent().unwrap().join(&name) };
    if direct.exists() { return store::target(&root, &direct); }
    let in_root = root.join(&name);
    if in_root.exists() { return store::target(&root, &in_root); }
    if name.components().count() != 1 { return Err("That linked note was not found.".into()); }
    // Short Obsidian links may name a note anywhere in the vault. Walk only on demand,
    // skip hidden directories and symlinks, and refuse ambiguity instead of guessing.
    let mut dirs = vec![root.clone()];
    let mut found = None;
    let mut visited = 0;
    while let Some(dir) = dirs.pop() {
        for entry in fs::read_dir(dir).map_err(|_| "A vault folder could not be searched.")? {
            let entry = entry.map_err(|_| "A vault entry could not be searched.")?;
            visited += 1;
            if visited > 100_000 { return Err("This vault is too large for short-link lookup; use a full note path.".into()); }
            if entry.file_name().to_string_lossy().starts_with('.') { continue; }
            let kind = entry.file_type().map_err(|_| "A vault entry could not be read.")?;
            if kind.is_dir() { dirs.push(entry.path()); }
            if kind.is_file() && entry.file_name() == name.as_os_str() {
                if found.is_some() { return Err("More than one note has this name. Use a folder-qualified link.".into()); }
                found = Some(entry.path());
            }
        }
    }
    store::target(&root, &found.ok_or("That linked note was not found.")?)
}
