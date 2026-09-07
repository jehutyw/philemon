import QtQuick
import "." as Philemon
import "js/Notes.js" as Notes

Item {
    id: root
    property var items: []
    property int current: -1
    property int closePending: -1
    property string notice: ""
    readonly property bool active: root.current >= 0 && root.current < root.items.length
    readonly property bool hasUnsaved: root.items.some(function (n) { return Notes.dirty(n) })
    readonly property bool busy: service.busy
    readonly property int stripHeight: root.items.length ? Theme.chromeHeight : 0
    readonly property var note: root.active ? root.items[root.current] : null
    signal filesRequested()

    function showFiles() { root.current = -1; root.closePending = -1; root.filesRequested() }
    function select(index) { root.current = index; root.closePending = -1; root.notice = "" }
    function changed(text) {
        if (!root.note) return
        var items = root.items.slice()
        items[root.current] = Object.assign({}, root.note, {text: text})
        root.items = items
    }
    function toggleEdit() {
        if (!root.note) return
        var items = root.items.slice()
        items[root.current] = Object.assign({}, root.note, {editing: !root.note.editing})
        root.items = items
    }
    function open(path, vault) {
        for (var i = 0; i < root.items.length; i++) {
            if (root.items[i].path === path) { select(i); return }
        }
        if (root.items.length >= 9) { root.notice = "Close a note before opening another (nine-note limit)."; return }
        if (!service.send({c: "load", path: path, vault: vault})) root.notice = "A note operation is still running. Try again shortly."
    }
    function save() {
        if (!root.note || root.busy) return
        root.notice = "Saving…"
        service.send({c: "save", path: root.note.path, vault: root.note.vault,
                      text: root.note.text, original: root.note.original})
    }
    function follow(link) {
        if (!root.note || root.busy) return
        root.notice = "Opening linked note…"
        service.send({c: "resolve", path: root.note.path, vault: root.note.vault, link: Notes.linkTarget(link)})
    }
    function close(index) {
        if (root.busy) { root.notice = "Wait for the note operation to finish."; return }
        select(index)
        if (Notes.dirty(root.items[index])) {
            root.closePending = index
            root.notice = "Unsaved changes. Save, discard, or keep editing."
        } else discard()
    }
    function discard() {
        if (!root.active || root.busy) return
        var remaining = root.items.slice()
        remaining.splice(root.current, 1)
        root.items = remaining
        root.closePending = -1
        root.current = remaining.length ? Math.min(root.current, remaining.length - 1) : -1
        root.notice = ""
        if (!root.active) root.filesRequested()
    }
    function reload() {
        if (!root.note || root.busy) return
        if (Notes.dirty(root.note)) {
            root.notice = "Copy your edits first, then close and discard this tab to reopen the disk version."
            return
        }
        service.send({c: "reload", path: root.note.path, vault: root.note.vault})
    }
    function guardClose() {
        if (!root.hasUnsaved && !root.busy) return false
        for (var i = 0; i < root.items.length; i++) {
            if (Notes.dirty(root.items[i])) { root.current = i; break }
        }
        root.notice = root.busy ? "Wait for the note operation before closing Philemon." : "Save or close and discard your unsaved notes before closing Philemon."
        return true
    }

    Connections {
        target: Philemon.Obsidian
        function onNoteRequested(path, vault) { root.open(path, vault) }
    }
    Philemon.NoteBackend {
        id: service
        onAnswered: function (request, reply) {
            if (!reply.ok) { root.notice = reply.error; return }
            var index = root.items.findIndex(function (n) { return n.path === reply.path })
            if (request.c === "save") {
                if (index >= 0) {
                    var savedItems = root.items.slice()
                    savedItems[index] = Object.assign({}, savedItems[index], {original: reply.text})
                    root.items = savedItems
                    if (root.closePending === index && !Notes.dirty(root.items[index])) root.discard()
                }
                root.notice = "Saved."
                return
            }
            if (index >= 0 && request.c !== "reload") { root.select(index); return }
            var note = {path: reply.path, vault: request.vault, text: Notes.source(reply.text), original: reply.text, editing: false}
            var items = root.items.slice()
            if (index >= 0) items[index] = note
            else {
                if (items.length >= 9) { root.notice = "Close a note before opening another (nine-note limit)."; return }
                items.push(note); index = items.length - 1
            }
            root.items = items
            root.select(index)
        }
    }
    Philemon.NoteTabs {
        id: tabs
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.stripHeight
        workspace: root
    }
    Loader {
        anchors.top: tabs.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        active: root.active
        sourceComponent: Philemon.NotePage { workspace: root }
    }
    // Notices must also be visible when an initial open fails from the Files workspace.
    Rectangle {
        visible: !root.active && root.notice.length > 0
        anchors.top: tabs.bottom
        anchors.right: parent.right
        width: Math.min(parent.width, 620)
        height: failedText.implicitHeight + 24
        color: Theme.color.surface
        Text { id: failedText; anchors.fill: parent; anchors.margins: 12; text: root.notice; color: Theme.color.foreground; wrapMode: Text.Wrap; textFormat: Text.PlainText }
        TapHandler { onTapped: root.notice = "" }
    }
}
