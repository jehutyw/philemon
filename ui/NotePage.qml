import QtQuick
import "." as Philemon
import "js/Notes.js" as Notes

Rectangle {
    id: root
    property var workspace
    readonly property var note: workspace.note
    color: Theme.color.background
    // Consume clicks in the document margin rather than selecting files underneath it.
    MouseArea { anchors.fill: parent }
    Column {
        id: toolbar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 8
        Text {
            width: parent.width
            text: root.note ? root.note.path : ""
            color: Theme.color.muted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.caption
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
        }
        Flow {
            width: parent.width
            spacing: 8
            Philemon.DialogButton { label: root.note && root.note.editing ? "Read" : "Edit source"; onActivated: workspace.toggleEdit() }
            Philemon.DialogButton { label: workspace.busy ? "Working…" : "Save (Ctrl+S)"; primary: true; enabled: !workspace.busy; onActivated: workspace.save() }
            Philemon.DialogButton { label: "Reload"; enabled: !workspace.busy; onActivated: workspace.reload() }
            Philemon.DialogButton { label: "Close note"; onActivated: workspace.close(workspace.current) }
            Philemon.DialogButton { visible: workspace.closePending >= 0; label: "Discard changes"; onActivated: workspace.discard() }
            Philemon.DialogButton { visible: workspace.closePending >= 0; label: "Keep editing"; onActivated: { workspace.closePending = -1; workspace.notice = "" } }
        }
        Text {
            width: parent.width
            text: workspace.notice || (Notes.dirty(root.note) ? "Unsaved changes" : "Saved on disk")
            color: Theme.color.muted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.caption
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
    }
    Flickable {
        id: scroll
        anchors.top: toolbar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        clip: true
        contentWidth: width
        contentHeight: body.item ? body.item.height : 0
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: body
            width: scroll.width
            sourceComponent: root.note && root.note.editing ? editor : reader
        }
    }
    Connections {
        target: workspace
        function onCurrentChanged() { scroll.contentY = 0 }
    }
    Component {
        id: editor
        TextEdit {
            objectName: "noteEditor"
            width: body.width
            height: Math.max(scroll.height, contentHeight)
            text: root.note ? root.note.text : ""
            textFormat: TextEdit.PlainText
            color: Theme.color.foreground
            selectionColor: Theme.color.accent
            selectedTextColor: Theme.color.background
            font.family: Theme.font.family
            font.pixelSize: Theme.font.bodySmall
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            activeFocusOnPress: true
            onTextEdited: workspace.changed(text)
            onCursorRectangleChanged: {
                if (cursorRectangle.y < scroll.contentY) scroll.contentY = cursorRectangle.y
                else if (cursorRectangle.y + cursorRectangle.height > scroll.contentY + scroll.height)
                    scroll.contentY = cursorRectangle.y + cursorRectangle.height - scroll.height
            }
            Keys.onPressed: function (event) {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) { workspace.save(); event.accepted = true }
            }
            Component.onCompleted: forceActiveFocus()
        }
    }
    Component {
        id: reader
        TextEdit {
            objectName: "noteReader"
            width: body.width
            height: Math.max(scroll.height, contentHeight)
            text: root.note ? Notes.preview(root.note.text) : ""
            textFormat: TextEdit.MarkdownText
            palette.link: Theme.color.accent
            palette.linkVisited: Theme.color.accent
            color: Theme.color.foreground
            selectionColor: Theme.color.accent
            selectedTextColor: Theme.color.background
            font.family: Theme.font.family
            font.pixelSize: Theme.font.bodySmall
            wrapMode: TextEdit.Wrap
            readOnly: true
            selectByMouse: true
            onLinkActivated: function (link) { workspace.follow(link) }
            Keys.onPressed: function (event) {
                if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) { workspace.save(); event.accepted = true }
            }
            Component.onCompleted: forceActiveFocus()
        }
    }
}
