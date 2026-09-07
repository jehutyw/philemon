use super::{links, store};
use crate::backend::testdir::TestDir;
use std::fs;
use std::os::unix::fs::{symlink, PermissionsExt};

fn vault(tag: &str) -> TestDir {
    let d = TestDir::new(tag);
    d.dir(".obsidian");
    d
}

#[test]
fn save_preserves_source_bom_crlf_permissions_and_private_backup() {
    let d = vault("notes-save");
    let old = "\u{feff}---\r\ntags: [work]\r\n---\r\n# café 🌱\r\n[[Other|Alias]]\r\n";
    let path = d.file("Note.md", old);
    fs::set_permissions(&path, fs::Permissions::from_mode(0o640)).unwrap();
    let backups = d.join("backups");
    let text = "---\ntags: [work]\n---\n# café 🌱\n[[Other|Alias]]\nEdited\n";
    let saved = store::save_with_backups(&path, old, text, &backups).unwrap();
    assert_eq!(saved, format!("\u{feff}{}", text.replace('\n', "\r\n")));
    assert_eq!(fs::read_to_string(&path).unwrap(), saved);
    assert_eq!(fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o640);
    let backup = fs::read_dir(&backups).unwrap().map(|e| e.unwrap().path()).find(|p| p.extension().unwrap() == "md").unwrap();
    assert_eq!(fs::read_to_string(&backup).unwrap(), old);
    assert_eq!(fs::metadata(&backup).unwrap().permissions().mode() & 0o777, 0o600);
    assert!(!fs::read_dir(d.path()).unwrap().any(|e| e.unwrap().file_name().to_string_lossy().starts_with(".philemon-note-")));
}

#[test]
fn conflict_does_not_overwrite_external_edits() {
    let d = vault("notes-conflict");
    let path = d.file("Note.md", "original");
    fs::write(&path, "external edit").unwrap();
    assert!(store::save_with_backups(&path, "original", "my edit", &d.join("backups")).unwrap_err().contains("Changed outside"));
    assert_eq!(store::read(&path).unwrap(), "external edit");
    assert!(!d.join("backups").exists());
}

#[test]
fn backup_failure_does_not_touch_note() {
    let d = vault("notes-backup-failure");
    let path = d.file("Note.md", "old");
    let obstruction = d.file("backups", "not a directory");
    assert!(store::save_with_backups(&path, "old", "new", &obstruction).is_err());
    assert_eq!(store::read(&path).unwrap(), "old");
}

#[test]
fn invalid_and_oversized_notes_are_refused() {
    let d = vault("notes-invalid");
    let file = d.file("Big.md", &"x".repeat(store::LIMIT + 1));
    assert!(store::read(&file).is_err());
    fs::write(&file, [255u8]).unwrap();
    assert!(store::read(&file).is_err());
    fs::write(&file, b"binary\0data").unwrap();
    assert!(store::read(&file).is_err());
    assert!(store::target(d.path(), &d.dir("Folder.md")).is_err());
    assert!(store::target(d.path(), &d.file("File.pdf", "x")).is_err());
}

#[test]
fn symlinks_cannot_escape_the_vault_and_hardlinks_are_not_replaced() {
    let d = vault("notes-links");
    let outside = TestDir::new("notes-outside");
    let external = outside.file("External.md", "outside");
    symlink(&external, d.join("Escape.md")).unwrap();
    assert!(store::target(d.path(), &d.join("Escape.md")).is_err());
    let note = d.file("Inside.md", "inside");
    symlink(&note, d.join("Alias.md")).unwrap();
    assert_eq!(store::target(d.path(), &d.join("Alias.md")).unwrap(), note);
    fs::hard_link(&note, d.join("Hard.md")).unwrap();
    assert!(store::save_with_backups(&note, "inside", "new", &d.join("backups")).is_err());
}

#[test]
fn links_resolve_relative_root_and_unique_short_names() {
    let d = vault("notes-resolve");
    d.dir("one"); d.dir("two");
    let from = d.file("one/From.md", "links");
    let local = d.file("one/Local.md", "local");
    let root = d.file("Root.md", "root");
    let other = d.file("two/café note.md", "other");
    assert_eq!(links::resolve(d.path(), &from, "Local#Heading").unwrap(), local);
    assert_eq!(links::resolve(d.path(), &from, "../Root.md").unwrap(), root);
    assert_eq!(links::resolve(d.path(), &from, "Root").unwrap(), root);
    assert_eq!(links::resolve(d.path(), &from, "caf%C3%A9%20note.md").unwrap(), other);
    assert!(links::resolve(d.path(), &from, "https://example.org/Note.md").is_err());
    assert!(links::resolve(d.path(), &from, "Missing").is_err());
}

#[test]
fn ambiguous_short_links_and_config_notes_are_refused() {
    let d = vault("notes-ambiguous");
    d.dir("one"); d.dir("two");
    let from = d.file("From.md", "links");
    d.file("one/Duplicate.md", "one"); d.file("two/Duplicate.md", "two");
    d.file(".obsidian/config.md", "private");
    assert!(links::resolve(d.path(), &from, "Duplicate").unwrap_err().contains("More than one"));
    assert!(links::resolve(d.path(), &from, ".obsidian/config.md").is_err());
}

#[test]
fn read_only_note_and_deleted_note_do_not_get_recreated() {
    let d = vault("notes-readonly");
    let path = d.file("Note.md", "old");
    fs::set_permissions(&path, fs::Permissions::from_mode(0o444)).unwrap();
    assert!(store::save_with_backups(&path, "old", "new", &d.join("backups")).is_err());
    fs::remove_file(&path).unwrap();
    assert!(store::save_with_backups(&path, "old", "new", &d.join("backups")).is_err());
    assert!(!path.exists());
}

#[test]
fn protocol_roundtrips_unicode_and_multiline_source() {
    let d = vault("notes-protocol");
    let path = d.file("Note.md", "# 🌱\n[[Other]]\n\"text\"\n");
    let command = format!("{{\"id\":42,\"c\":\"load\",\"vault\":\"{}\",\"path\":\"{}\"}}", d.path().display(), path.display());
    let reply = super::reply(&command);
    assert!(crate::json::field_bool(&reply, "ok"));
    assert_eq!(crate::json::field_usize(&reply, "id"), Some(42));
    assert_eq!(crate::json::field_str(&reply, "text").unwrap(), "# 🌱\n[[Other]]\n\"text\"\n");
}
