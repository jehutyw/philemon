pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "js/Templates.js" as TemplatesJs

// The document types the desktop ships, read once per session the way ui/Taildrop.qml reads its
// peers. Everything that knows where templates live is here; ui/js/Menu.js only renders the list.
Item {
    id: root

    Component.onCompleted: root.refresh()

    // [{id, label}] for the New file flyout: the three built-ins first, then whatever was found.
    property var entries: TemplatesJs.entries([])

    function refresh() {
        if (!scan.running)
            scan.running = true
    }

    // The flyout's id carries the name and the template either side of a NUL, see js/Templates.js.
    // The backend answers "made" and ui/PaneWire.qml puts the new row straight into rename.
    function create(pane, id) {
        var pick = TemplatesJs.split(id)
        pane.backend.newfile(pane.path, pick.name, pick.from)
    }

    // One grep, not a walk: -r with --include reads both directories and every .desktop in them in
    // a single process, and a directory that is not there is a line on stderr nothing collects.
    // argv-direct, so neither path reaches a shell.
    Process {
        id: scan
        command: ["grep", "-H", "-E", "^(Name|URL)=", "-r", "--include=*.desktop",
                  "/usr/share/templates",
                  (Quickshell.env("XDG_TEMPLATES_DIR") || Quickshell.env("HOME") + "/Templates")]
        stdout: StdioCollector { id: scanOut; waitForEnd: true }
        // grep exits 1 when it matched nothing and 2 when a directory is missing, and both are
        // ordinary here: a box with no templates still gets the three built-ins.
        onExited: root.entries = TemplatesJs.entries(TemplatesJs.parse(scanOut.text))
    }
}
