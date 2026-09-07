import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var pending: null
    readonly property bool busy: root.pending !== null
    property int serial: 0
    signal answered(var request, var reply)

    function failed() {
        if (!root.pending) return
        var request = root.pending
        root.pending = null
        root.answered(request, {ok: false, error: "The note service stopped or could not start. Your edits are still in the tab."})
    }

    function send(request) {
        if (root.busy) return false
        request.id = ++root.serial
        root.pending = request
        if (child.running) child.write(JSON.stringify(request) + "\n")
        else child.running = true
        return true
    }

    Process {
        id: child
        command: [Quickshell.env("PHILEMON_BIN") || "philemon", "--notes"]
        stdinEnabled: true
        onStarted: if (root.pending) child.write(JSON.stringify(root.pending) + "\n")
        stdout: SplitParser {
            onRead: function (data) {
                var reply
                try { reply = JSON.parse(data) } catch (_) { return }
                if (!root.pending || reply.id !== root.pending.id) return
                var request = root.pending
                root.pending = null
                root.answered(request, reply)
            }
        }
        onRunningChanged: if (!child.running) root.failed()
        onExited: root.failed()
    }
}
