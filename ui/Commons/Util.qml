pragma Singleton
import QtQuick

QtObject {
    function alpha(value, opacity) {
        var c = Qt.color(value)
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, opacity)))
    }
}
