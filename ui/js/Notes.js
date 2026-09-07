.pragma library

function source(text) { return String(text || "").replace(/^\uFEFF/, "").replace(/\r\n/g, "\n") }
function dirty(note) { return note && note.text !== source(note.original) }
function label(note) { return note.path.substring(note.path.lastIndexOf("/") + 1) + (dirty(note) ? " *" : "") }

// Render a copy only; the editable source never passes through Markdown serialization.
// Images/embeds stay as text in this first reader, preventing implicit network requests.
function preview(text) {
    var fence = ""
    return text.split("\n").map(function (line) {
        var marker = line.match(/^\s*(`{3,}|~{3,})/)
        if (marker) {
            if (!fence) fence = marker[1][0]
            else if (marker[1][0] === fence) fence = ""
            return line
        }
        if (fence || /^(    |\t)/.test(line)) return line
        // Leave inline code untouched, including wikilink-looking text inside it.
        return line.split(/(`+[^`]*`+)/g).map(function (part) {
            if (part[0] === "`") return part
            part = part.replace(/</g, "&lt;").replace(/>/g, "&gt;")
            part = part.replace(/!\[\[([^\]]+)\]\]/g, function (_, name) { return "`Embed: " + name.replace(/`/g, "") + "`" })
            part = part.replace(/!\[([^\]]*)\]\([^)]*\)/g, function (_, name) { return "`Image: " + name.replace(/`/g, "") + "`" })
            part = part.replace(/!\[([^\]]*)\]/g, function (_, name) { return "`Image: " + name.replace(/`/g, "") + "`" })
            return part.replace(/\[\[([^\]]+)\]\]/g, function (_, body) {
                var split = body.indexOf("|")
                var target = split < 0 ? body : body.substring(0, split)
                var label = split < 0 ? body : body.substring(split + 1)
                return "[" + label.replace(/[\[\]\\]/g, "\\$&") + "](philemon-note:" + encodeURIComponent(target) + ")"
            })
        }).join("")
    }).join("\n")
}

function linkTarget(link) {
    if (link.indexOf("philemon-note:") === 0) {
        // Keep the percent encoding intact; the note service decodes it exactly once,
        // so a filename containing a literal "%20" cannot become a space.
        return link.substring("philemon-note:".length)
    }
    return link
}
