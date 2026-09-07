import QtQuick
import Quickshell
import Quickshell.Io
import "js/Taildrop.js" as TaildropJs

// The context menu's own Service, the same shape as ui/NetworkMounts.qml: this is the only thing
// here that touches tailscale, ui/ContextMenu.qml only reads "peers" and renders it.
Item {
    id: root

    // [{id, label, address}], the reachable Taildrop-eligible peers; empty self-hides the menu
    // entry entirely, which is also what a box with no tailscale on PATH and a logged-out
    // tailnet both reduce to, with no separate probe needed.
    property var peers: []
    // onExited can race the StdioCollector's own text, see ui/NetworkMounts.qml's header comment.
    property string _statusOutput: ""

    function refresh() {
        if (statusProcess.running)
            return
        statusProcess.running = true
    }

    // argv-direct and detached: the script owns its own success/failure notification, see
    // docs/superpowers/specs/2026-08-31-philemon-operations-design.md "4.1 Taildrop".
    function send(peerId, paths) {
        var peer = TaildropJs.byId(root.peers, peerId)
        if (!peer)
            return
        Quickshell.execDetached(["tailscale", "file", "cp"].concat(paths).concat([peer.address + ":"]))
    }

    // ui/Pane.qml's own dispatch-confirmation message reads a name, not the id chosen() carries.
    function labelFor(peerId) {
        var peer = TaildropJs.byId(root.peers, peerId)
        return peer ? peer.label : "that peer"
    }

    Process {
        id: statusProcess
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            id: statusOut
            waitForEnd: true
            onStreamFinished: root._statusOutput = text
        }
        onExited: function (exitCode) {
            var body = exitCode === 0 ? (statusOut.text || root._statusOutput || "") : ""
            root.peers = TaildropJs.parsePeers(body)
        }
    }
}
