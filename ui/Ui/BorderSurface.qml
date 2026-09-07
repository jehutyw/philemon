import QtQuick

Rectangle {
    id: root
    property var borderSpec: ({ color: "transparent", width: 0 })
    property real padding: 0
    property real topPadding: padding
    property real rightPadding: padding
    property real bottomPadding: padding
    property real leftPadding: padding
    readonly property real contentTopInset: border.width + topPadding
    readonly property real contentRightInset: border.width + rightPadding
    readonly property real contentBottomInset: border.width + bottomPadding
    readonly property real contentLeftInset: border.width + leftPadding
    border.color: borderSpec && borderSpec.color ? borderSpec.color : "transparent"
    border.width: borderSpec && borderSpec.width ? borderSpec.width : 0
}
