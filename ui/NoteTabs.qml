import QtQuick
import "." as Philemon
import "js/Notes.js" as Notes

Rectangle {
    id: root
    property var workspace
    color: Theme.color.surface
    visible: height > 0
    Flickable {
        anchors.fill: parent
        contentWidth: strip.width
        contentHeight: height
        clip: true
        Row {
            id: strip
            height: root.height
            Philemon.DialogButton {
                height: strip.height
                label: "Files"
                primary: !workspace.active
                onActivated: workspace.showFiles()
            }
            Repeater {
                model: workspace.items
                delegate: Row {
                    required property var modelData
                    required property int index
                    height: strip.height
                    Philemon.DialogButton {
                        height: strip.height
                        label: Notes.label(modelData)
                        primary: workspace.current === index
                        onActivated: workspace.select(index)
                    }
                    Philemon.DialogButton {
                        height: strip.height
                        label: "×"
                        Accessible.name: "Close " + Notes.label(modelData)
                        onActivated: workspace.close(index)
                    }
                }
            }
        }
    }
}
