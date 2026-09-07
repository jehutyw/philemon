pragma Singleton
import QtQuick

QtObject {
    id: root
    property int cornerRadius: 6
    property real fontScale: 1
    property real spacingScale: 1
    property var values: ({})

    readonly property QtObject font: QtObject {
        readonly property string family: String(root.values["font.family"] || "monospace")
        readonly property string resolvedFamily: family
        readonly property int baseSize: Number(root.values["font.base-size"] || 12)
        readonly property int body: Math.round(baseSize * 1.16)
        readonly property int bodySmall: baseSize
        readonly property int caption: Math.max(9, Math.round(baseSize * 0.84))
        readonly property int icon: Math.round(baseSize * 1.34)
    }
    readonly property QtObject spacing: QtObject {
        readonly property int hairline: root.space(1)
        readonly property int controlPaddingY: root.space(6)
        readonly property int rowGap: root.space(8)
        readonly property int rowPaddingX: root.space(12)
        readonly property int panelGap: root.space(14)
        readonly property int panelPadding: root.space(18)
    }
    readonly property real hoverFillAlpha: 0.08
    readonly property color normalFill: Util.alpha(Color.foreground, 0.04)
    readonly property color hoverFill: Util.alpha(Color.foreground, hoverFillAlpha)
    readonly property color selectedFill: Util.alpha(Color.foreground, 0.18)
    readonly property color selectedAccentFill: Util.alpha(Color.accent, 0.18)
    readonly property color selectionFill: Util.alpha(Color.foreground, 0.35)
    readonly property int normalBorderWidth: 1

    function space(px) { return Math.max(1, Math.round(Number(px) * spacingScale * fontScale)) }
    function applyShellValues(next) {
        values = next || ({})
        var scale = Number(values["spacing.scale"])
        spacingScale = isFinite(scale) && scale > 0 ? scale : 1
        var base = Number(values["font.base-size"])
        fontScale = isFinite(base) && base > 0 ? base / 12 : 1
    }
    function scheduleRefresh() {}
}
