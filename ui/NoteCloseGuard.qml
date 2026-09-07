import QtQuick
import Quickshell

QtObject {
    id: root
    property var window
    property var workspace
    signal quitRequested()
    // Reach the QQuickWindow through its content item's standard Window attachment.
    // Veto its native close event before
    // it hides: waiting for lastWindowClosed is too late on some window platforms.
    readonly property Connections nativeClose: Connections {
        target: root.window ? root.window.contentItem.Window.window : null
        function onClosing(event) {
            if (root.workspace.guardClose()) event.accepted = false
        }
    }
    readonly property Connections closeConnection: Connections {
        target: Quickshell
        function onLastWindowClosed() {
            if (root.workspace.guardClose()) {
                // Reopen after the native close event has finished updating visibility.
                Qt.callLater(function () { root.window.visible = true })
                return
            }
            root.quitRequested()
        }
    }
}
