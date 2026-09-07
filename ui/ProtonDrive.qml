import Quickshell
import Quickshell.Io
import QtQuick
import "js/ProtonDrive.js" as Drive

// proton-drive is a CLI, not a synced folder: there is no local directory to move a file into the
// way Dropbox has one, so an upload is this one call. Everything that touches the tool lives here.
Item {
    id: root

    // The writable root. "/" is not a folder, it lists the virtual ones (trash, photos, shared).
    readonly property string myFiles: "/my-files"

    signal started(int count)
    signal progress(string line)
    signal uploaded(int count)
    signal failed(int count)

    // The CLI writes this directory only once `auth login` has succeeded, so its presence is the
    // login gate the menu row needs. The binary on its own would offer an upload that always fails.
    readonly property bool ready: session.loaded
    // [{id, label}] for the menu's flyout, My files first and its folders under it.
    property var folders: [{ id: root.myFiles, label: "My files" }]

    property int pending: 0
    property int _done: 0

    function refresh() {
        if (root.ready && !folderList.running)
            folderList.running = true
    }

    function upload(paths, dest) {
        if (paths.length === 0 || job.running)
            return
        root.pending = paths.length
        root._done = 0
        // unbuffer, from expect, gives the child a pty: this CLI prints its progress only to a
        // terminal and falls back to a single summary line on a pipe. It is argv-direct, so a file
        // named with a backtick or $(...) never reaches a shell, which `script -c` could not promise.
        // The two strategies are not optional either. Without them the CLI prompts on a name that
        // already exists, and a prompt with no stdin is a process that never exits; neither value
        // chosen here destroys anything remote.
        job.command = ["unbuffer", "proton-drive", "filesystem", "upload",
                       "-f", "create-new-revision", "-d", "merge"]
            .concat(paths).concat([dest || root.myFiles])
        job.running = true
        root.started(paths.length)
    }

    FileView {
        id: session
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/proton-drive-cli"
        watchChanges: true
        printErrors: false
    }

    // Driven off the flag and not off FileView's onLoaded: that signal does not fire for a
    // directory here, while loaded still settles true, so a listing hung on it never ran.
    onReadyChanged: root.refresh()

    // Read once per session like ui/Taildrop.qml's peers, not per right click: the flyout's own
    // height would otherwise depend on a network reply arriving before the menu opened.
    Process {
        id: folderList
        command: ["proton-drive", "filesystem", "list", "-t", "folder", "-j", root.myFiles]
        stdout: StdioCollector { id: folderOut; waitForEnd: true }
        onExited: function (exitCode) {
            root.folders = Drive.parseFolders(exitCode === 0 ? folderOut.text : "", root.myFiles)
        }
    }

    Process {
        id: job
        // The progress redraw separates its frames with a carriage return, not a newline, so that
        // is the marker; the escapes it paints them with are stripped before anything is read.
        stdout: SplitParser {
            splitMarker: "\r"
            onRead: function (data) {
                var clean = String(data).replace(/\x1b\[[0-9;?]*[a-zA-Z]/g, "")
                var at = Drive.parseProgress(clean)
                if (at.done >= 0)
                    root._done = at.done
                if (at.percent >= 0 || at.done >= 0)
                    root.progress(Drive.progressText(root._done, root.pending, at.percent))
            }
        }
        onExited: function (exitCode) {
            if (exitCode === 0)
                root.uploaded(root.pending)
            else
                root.failed(root.pending)
        }
    }
}
