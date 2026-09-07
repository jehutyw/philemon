pragma Singleton
import QtQuick

QtObject {
    id: root
    property color foreground: "#cacccc"
    property color background: "#101315"
    property color accent: "#89b4fa"
    property color urgent: "#f38ba8"

    function loadColors(raw) {
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
            if (!m) continue
            if (m[1] === "foreground" || m[1] === "color7") foreground = m[2]
            else if (m[1] === "background" || m[1] === "color0") background = m[2]
            else if (m[1] === "accent" || m[1] === "color4") accent = m[2]
            else if (m[1] === "red" || m[1] === "color1") urgent = m[2]
        }
    }

    function loadShell(raw) { Style.applyShellValues(parseShell(raw)) }

    function parseShell(raw) {
        var out = {}, section = "", lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^\s+|\s+$/g, "")
            var s = line.match(/^\[([A-Za-z0-9_-]+)\]/)
            if (s) { section = s[1]; continue }
            var kv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*["']?([^"'#]+)["']?/)
            if (section && kv) out[section + "." + kv[1]] = kv[2].replace(/\s+$/g, "")
        }
        return out
    }
}
