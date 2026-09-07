use crate::paths;
use crate::thp;
use crate::vulkan;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

// exec rather than spawn, so the shell replaces this process and no pid is orphaned.
pub fn exec_qs(ui: &Path, start: Option<&str>, select: Option<&str>) -> i32 {
    let mut cmd = qs_command(ui.to_path_buf());
    if let Some(path) = start {
        cmd.env("PHILEMON_PATH", path);
    }
    if let Some(target) = select {
        cmd.env("PHILEMON_SELECT", target);
    }
    exec(cmd)
}

// philemon --pick <reply>: the picker window tools/philemon-portal opens for one portal request. Same shell
// and the same renderer choice, on a second entry point, so a chooser is not a second application.
pub fn pick(reply: &str) -> i32 {
    // Empty is absent, the rule paths::has_display() applies: a wrapper's unset variable is not a request.
    if !std::env::var_os("PHILEMON_PICKER").is_some_and(|value| !value.is_empty()) {
        eprintln!("philemon: --pick needs PHILEMON_PICKER, the portal request tools/philemon-portal puts in the environment");
        return 2;
    }
    if reply.is_empty() {
        eprintln!("philemon: --pick needs the reply file tools/philemon-portal names, and it was empty");
        return 2;
    }
    if !paths::has_display() {
        eprintln!("philemon: there is no graphical session to open a file chooser in");
        return 2;
    }
    let Some(ui) = paths::ui_dir() else {
        eprintln!("philemon: the shell config is missing, set PHILEMON_UI or install /usr/share/philemon/ui");
        return 2;
    };
    let mut cmd = qs_command(ui.join("picker.qml"));
    cmd.env("PHILEMON_PICKER_REPLY", reply);
    exec(cmd)
}

// The qs invocation both entry points share: the target, the binary the shell calls back into, and
// the renderer, which is chosen here because this is the last point that can hand it to qs.
fn qs_command(target: PathBuf) -> Command {
    let mut cmd = Command::new("qs");
    cmd.arg("-p").arg(target);
    if let Ok(binary) = std::env::current_exe() {
        cmd.env("PHILEMON_BIN", binary);
    }
    // Empty is absent, the rule paths::has_display() applies: a wrapper's unset variable is not a choice.
    if std::env::var_os("QSG_RHI_BACKEND").is_some_and(|value| !value.is_empty()) {
        // An explicit choice is the operator's, so it is neither replaced nor offered a retry.
        cmd.env_remove("PHILEMON_RENDERER_AUTOMATIC");
    } else if let Err(reason) = vulkan::usable() {
        // A silent downgrade hides a 2.4x memory regression, so the reason the probe found is said once.
        eprintln!("philemon: Vulkan is unusable, {reason}, so the shell starts on OpenGL");
        cmd.env("QSG_RHI_BACKEND", "opengl");
        cmd.env_remove("PHILEMON_RENDERER_AUTOMATIC");
    } else {
        // Vulkan is the measured fast path, and the marker is what permits the QML arm its one retry.
        cmd.env("QSG_RHI_BACKEND", "vulkan");
        cmd.env("PHILEMON_RENDERER_AUTOMATIC", "1");
    }
    cmd
}

fn exec(mut cmd: Command) -> i32 {
    // The setting is preserved across exec, so this is the last point that can hand it to qs.
    thp::disable();
    // exec() only returns on failure; the reason is elided, never shown raw.
    let _ = cmd.exec();
    eprintln!("philemon: could not start the shell, qs is not on PATH or failed to run");
    1
}
