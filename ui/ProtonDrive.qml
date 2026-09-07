import Quickshell
import Quickshell.Io
import QtQuick

// proton-drive is a CLI, not a synced folder: there is no local directory to move a file into the
// way Dropbox has one, so an upload is this one call. Everything that touches the tool lives here.
Item {
    id: root

    signal started(string name)
    signal uploaded(string name)
    signal failed(string name)

    // The CLI writes this directory only once `auth login` has succeeded, so its presence is the
    // login gate the menu row needs. The binary on its own would offer an upload that always fails.
    readonly property bool ready: session.loaded

    property string pending: ""

    function upload(path, name) {
        if (path.length === 0 || job.running)
            return
        root.pending = name
        // The two strategies are not optional. Without them the CLI prompts on a name that already
        // exists, and a prompt with no stdin is a process that never exits. Neither value chosen
        // here destroys anything remote: a new revision keeps the old one, a merge keeps both sides.
        // /my-files is the writable root; "/" lists the virtual ones (trash, photos, shared-with-me).
        job.command = ["proton-drive", "filesystem", "upload",
                       "-f", "create-new-revision", "-d", "merge", path, "/my-files"]
        job.running = true
        root.started(name)
    }

    FileView {
        id: session
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/proton-drive-cli"
        watchChanges: true
        printErrors: false
    }

    Process {
        id: job
        onExited: function (exitCode) {
            if (exitCode === 0)
                root.uploaded(root.pending)
            else
                root.failed(root.pending)
        }
    }
}
