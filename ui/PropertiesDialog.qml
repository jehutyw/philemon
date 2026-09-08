import QtQuick
import qs.Commons
import "." as Philemon
import "js/Properties.js" as Properties

// What the menu's Properties row opens. Every value is already in the listing's own rows reply, so
// this asks the backend for nothing and opens filled in; ui/js/Properties.js is the whole model.
Item {
    id: root

    property bool opened: false
    property Item focusHolder: null

    // The row the menu was raised over, its envelope's Kind table, and the directory holding it.
    property var row: null
    property var kinds: []
    property string dir: ""

    // The canvas draws the convert popup at 300; this one carries paths, so it takes the wider slot.
    readonly property int dialogWidth: 420

    readonly property var facts: Properties.rows(root.row, root.kinds, root.dir, Date.now())

    anchors.fill: parent
    visible: root.opened
    z: 2

    function open(row, kinds, dir) {
        root.row = row
        root.kinds = kinds
        root.dir = dir
        root.opened = true
        root.forceActiveFocus()
    }

    function close() {
        root.opened = false
        if (root.focusHolder)
            root.focusHolder.forceActiveFocus()
    }

    Keys.onEscapePressed: root.close()

    // A dimmed ground, and a click on it is a cancel, the same shape the convert popup already uses.
    Rectangle {
        anchors.fill: parent
        color: Theme.color.background
        opacity: 0.5

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Theme.space(root.dialogWidth)
        height: body.implicitHeight + 2 * Theme.spacing.rowPaddingX
        color: Theme.color.surface
        border.width: Theme.spacing.hairline
        border.color: Theme.color.muted
        radius: Style.cornerRadius

        Column {
            id: body
            width: parent.width
            y: Theme.spacing.rowPaddingX
            spacing: 0

            Text {
                x: Theme.spacing.rowPaddingX
                width: parent.width - 2 * Theme.spacing.rowPaddingX
                bottomPadding: Theme.spacing.gap
                text: "Properties"
                color: Theme.color.foreground
                font.family: Theme.font.family
                font.pixelSize: Theme.font.bodySmall
                font.bold: true
                textFormat: Text.PlainText
            }

            Rectangle {
                width: parent.width
                height: Theme.spacing.hairline
                color: Theme.color.muted
                opacity: 0.4
            }

            Item { width: 1; height: Theme.spacing.gap }

            // The same table the preview column draws its facts in, given a wider label column:
            // "Permissions" does not fit the gutter the preview's own twelve states share.
            Philemon.FactsTable {
                x: Theme.spacing.rowPaddingX
                width: parent.width - 2 * Theme.spacing.rowPaddingX
                rows: root.facts
                labelGuide: "Permissions "
            }
        }
    }
}
