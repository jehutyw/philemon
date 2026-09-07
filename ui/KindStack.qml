import QtQuick
import "." as Philemon

// The marks a multi-selection stacks in the preview frame, one per kind, front-most first. The
// canvas offsets 44 unit marks 11 across and 4 down, a quarter of the mark and an eleventh of it;
// both are measured against Theme.markSize because ui/Glyph.qml inks min(markSize, slot), so a step
// taken off a 46 unit slot would be two and a half times the mark it is offsetting.
Item {
    id: root

    // Glyph names, front-most first, as ui/js/Facts.js multiMarks builds them.
    property var marks: []

    readonly property int stepX: Math.round(Theme.markSize / 4)
    readonly property int stepY: Math.round(Theme.markSize / 11)
    // Every mark behind the front one is a step fainter, which is the canvas's 1.0, 0.7 and 0.4.
    readonly property real fade: 0.3
    readonly property int steps: Math.max(0, root.marks.length - 1)

    width: Theme.markSize + root.steps * root.stepX
    height: Theme.markSize + root.steps * root.stepY

    Repeater {
        model: root.marks

        delegate: Philemon.Glyph {
            required property string modelData
            required property int index
            // Model order paints back to front, so the front mark has to claim its own z.
            z: root.marks.length - index
            x: (root.steps - index) * root.stepX
            y: index * root.stepY
            width: Theme.markSize
            height: Theme.markSize
            name: modelData
            color: Theme.color.muted
            opacity: 1 - index * root.fade
        }
    }
}
