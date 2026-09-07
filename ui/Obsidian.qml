pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "js/Obsidian.js" as Vaults

QtObject {
    id: root
    property var entries: []
    signal noteRequested(string path, string vault)
    function openNote(path) {
        var matches = root.entries.filter(function (v) { return path.indexOf(v.path + "/") === 0 })
        matches.sort(function (a, b) { return b.path.length - a.path.length })
        if (matches.length) root.noteRequested(path, matches[0].path)
    }
    function favorites(existing) { return Vaults.favorites(existing, root.entries) }
    function isNote(path) { return Vaults.isNote(path, root.entries) }

    readonly property FileView registry: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/obsidian/obsidian.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.entries = Vaults.vaults(text())
        onLoadFailed: root.entries = []
    }
}
