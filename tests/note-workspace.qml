// The runner stages this alongside the UI, so qs.Commons resolves from its config root.
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "." as Philemon

ShellRoot {
    FloatingWindow {
        id: testWindow
        implicitWidth: 1000
        implicitHeight: 700
        Philemon.NoteWorkspace { id: workspace; anchors.fill: parent }
        Philemon.Opener { id: opener }
        FileView { id: externalWriter; path: Quickshell.env("PHILEMON_NOTE_TEST_VAULT") + "/Start.md" }
        Philemon.NoteCloseGuard { window: testWindow; workspace: tester.workspaceRef; onQuitRequested: tester.quitRequested = true }
        Item {
            id: tester
            property var workspaceRef: workspace
            property int step: 0
            property bool quitRequested: false
            TestEvent { id: events }
            function compare(a, b) { if (a !== b) throw new Error("step " + step + ": got " + a + ", expected " + b) }
            function verify(v) { if (!v) throw new Error("verification failed at step " + step) }
            function findChild(item, name) {
                if (item.objectName === name) return item
                var children = item.children || []
                for (var i = 0; i < children.length; i++) { var found = findChild(children[i], name); if (found) return found }
                return null
            }
            Timer {
                interval: 150; running: true; repeat: true
                onTriggered: {
                    if (workspace.busy) return
                    try { tester.tick() } catch (e) { console.log("NOTE WORKSPACE FAIL: " + e); Qt.exit(1) }
                }
            }
            function tick() {
                var vault = Quickshell.env("PHILEMON_NOTE_TEST_VAULT")
                if (step === 0) {
                Philemon.Obsidian.entries = [{path: vault}]
                opener.open(vault + "/Start.md")
                } else if (step === 1) {
                compare(workspace.items.length, 1)
                compare(workspace.active, true)
                compare(workspace.hasUnsaved, false)
                workspace.toggleEdit()
                } else if (step === 2) {
                var editor = findChild(workspace, "noteEditor")
                if (!editor) throw new Error("noteEditor was not instantiated")
                editor.forceActiveFocus()
                console.log("Editor focus=" + editor.activeFocus)
                events.keyClick(Qt.Key_End, Qt.ControlModifier, 0)
                var added = "Added inside Philemon"
                for (var k = 0; k < added.length; k++) events.keyClickChar(added[k], Qt.NoModifier, 0)
                console.log("Edited=" + workspace.hasUnsaved + "; contains input=" + (workspace.note.text.indexOf(added) >= 0))
                compare(workspace.hasUnsaved, true)
                verify(workspace.note.text.indexOf("Added inside Philemon") >= 0)
                events.keyClick(Qt.Key_S, Qt.ControlModifier, 0)
                } else if (step === 3) {
                compare(workspace.hasUnsaved, false)
                compare(workspace.notice, "Saved.")
                workspace.toggleEdit()
                } else if (step === 4) {
                var reader = findChild(workspace, "noteReader")
                verify(reader !== null)
                var hit = null
                for (var y = 0; y < Math.min(reader.height, 350) && !hit; y += 4) {
                    for (var x = 0; x < reader.width && !hit; x += 4) {
                        if (reader.linkAt(x, y) === "philemon-note:Next") hit = {x: x, y: y}
                    }
                }
                verify(hit !== null)
                events.mouseClick(reader, hit.x, hit.y, Qt.LeftButton, Qt.NoModifier, 0)
                } else if (step === 5) {
                compare(workspace.items.length, 2)
                verify(workspace.note.path.endsWith("/Next.md"))
                workspace.changed(workspace.note.text + "Unsaved")
                workspace.Window.window.close()
                } else if (step === 6) {
                compare(testWindow.visible, true)
                compare(quitRequested, false)
                workspace.showFiles()
                compare(workspace.active, false)
                compare(workspace.hasUnsaved, true)
                workspace.select(1)
                compare(workspace.guardClose(), true)
                workspace.close(1)
                compare(workspace.closePending, 1)
                compare(workspace.items.length, 2)
                workspace.discard()
                compare(workspace.items.length, 1)
                compare(workspace.guardClose(), false)
                compare(workspace.hasUnsaved, false)
                } else if (step === 7) {
                workspace.grabToImage(function (result) { result.saveToFile(Quickshell.env("PHILEMON_NOTE_TEST_IMAGE")) })
                workspace.changed(workspace.note.text + "Local conflict edit")
                externalWriter.setText("Changed in another editor\n")
                externalWriter.waitForJob()
                workspace.save()
                } else if (step === 8) {
                verify(workspace.notice.indexOf("Changed outside Philemon") >= 0)
                verify(workspace.note.text.indexOf("Local conflict edit") >= 0)
                compare(workspace.hasUnsaved, true)
                workspace.reload()
                verify(workspace.notice.indexOf("Copy your edits first") >= 0)
                workspace.close(0)
                workspace.discard()
                opener.open(vault + "/Start.md")
                } else if (step === 9) {
                compare(workspace.note.text, "Changed in another editor\n")
                compare(workspace.hasUnsaved, false)
                console.log("NOTE WORKSPACE PASS: keyboard edit/save, read link, tabs and unsaved close guard")
                console.log("NOTE CONFLICT PASS: external version protected, local edit retained, explicit discard and reload")
                Qt.exit(0)
                }
                step++
            }
        }
    }
    Timer { interval: 15000; running: true; onTriggered: { console.log("NOTE WORKSPACE FAIL: timed out"); Qt.exit(1) } }
}
