use crate::thp;
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::Command;

// exec rather than spawn, so the shell replaces this process and no pid is orphaned.
pub fn exec_qs(ui: &Path, start: Option<&str>, select: Option<&str>) -> i32 {
    let mut cmd = Command::new("qs");
    cmd.arg("-p").arg(ui);
    if let Some(path) = start {
        cmd.env("PHILEMON_PATH", path);
    }
    if let Some(target) = select {
        cmd.env("PHILEMON_SELECT", target);
    }
    // The setting is preserved across exec, so this is the last point that can hand it to qs.
    thp::disable();
    // exec() only returns on failure; the reason is elided, never shown raw.
    let _ = cmd.exec();
    eprintln!("philemon: could not start the shell, qs is not on PATH or failed to run");
    1
}
