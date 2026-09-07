import QtQuick
import QtQuick.Shapes

// The phi as the activity mark: a stroke-dash crawl along the brand path, never a rotation.
// This and EmptyState's PhilemonMark are the only two places the mark appears; rows and menus
// never draw it, per the icon-language spec.
Item {
    id: root

    property color color: Theme.color.muted
    // The mark draws on the same 24 unit grid as every Glyph, scaled to the slot.
    readonly property real grid: 24
    // ui/PhilemonMark.qml's own centreline sum, kept here so one period is derived and never
    // written down twice: a path edit that changes the length cannot leave a visible loop seam.
    readonly property real markUnits: 52 + 6 * Math.SQRT2
    readonly property real period: root.markUnits / 2
    readonly property real markScale: Math.min(root.width, root.height) / root.grid

    Shape {
        width: root.grid
        height: root.grid
        x: (root.width - root.grid * root.markScale) / 2
        y: (root.height - root.grid * root.markScale) / 2
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { xScale: root.markScale; yScale: root.markScale }

        ShapePath {
            id: crawl
            strokeColor: root.color
            fillColor: "transparent"
            // A brand mark, not a cut glyph: the phi keeps the brand's 2 and is exempt from Theme.strokeWidth on purpose.
            strokeWidth: 2
            capStyle: ShapePath.SquareCap
            joinStyle: ShapePath.MiterJoin
            strokeStyle: ShapePath.DashLine
            // Dash units are strokeWidth multiples, so one period is the centreline over the 2 above.
            // Dash and gap sum to exactly that period, holding the old mark's 30:27 split, and the
            // animation walks one period per cycle, so the loop point stays invisible.
            dashPattern: [root.period * 30 / 57, root.period * 27 / 57]
            PathSvg { path: "M12 2V7H15L18 10V17H9L6 14V7H12V22" }
        }
    }

    NumberAnimation {
        target: crawl
        property: "dashOffset"
        from: 0
        to: -root.period
        duration: 1600
        loops: Animation.Infinite
        // Item.visible reads effective visibility, so a hidden ancestor stops the crawl too.
        running: root.visible
    }
}
