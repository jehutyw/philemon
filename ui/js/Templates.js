.pragma library

// The New file flyout's entries. Three are always there, and the rest are whatever the desktop
// already ships: /usr/share/templates and ~/Templates are the XDG locations Dolphin and Nautilus
// read, so a document type installed by a package appears here with nothing added to this tree.

// A submenu entry carries one id, so the two facts an entry needs travel in it either side of a
// separator: the name to create, and the template whose bytes fill it. NUL is the separator because
// it is the one byte a POSIX path cannot hold, so neither half can ever contain it; a printable
// choice would only be unlikely.
var SEP = "\u0000"

// The three that need no template at all: an empty file is a create with nothing copied into it.
var BUILTIN = [
    { label: "Empty file", name: "New File", from: "" },
    { label: "Text file", name: "New File.txt", from: "" },
    { label: "Markdown", name: "New File.md", from: "" }
]

function entryId(name, from) {
    return name + SEP + from
}

// The two halves back, for ui/Pane.qml's own dispatch.
function split(id) {
    var at = String(id || "").indexOf(SEP)
    if (at < 0)
        return { name: String(id || ""), from: "" }
    return { name: id.substring(0, at), from: id.substring(at + SEP.length) }
}

// Sample input, `grep -H -E '^(Name|URL)=' -r --include=*.desktop /usr/share/templates ~/Templates`:
// /usr/share/templates/soffice.odt.desktop:Name=LibreOffice Writer  ...
// /usr/share/templates/soffice.odt.desktop:URL=.source/soffice.odt
// The URL is relative to the .desktop's own directory, which is why the path is kept: two template
// directories both holding ".source/x.odt" would otherwise collapse onto one file.
function parse(raw) {
    var found = {}
    var order = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var at = lines[i].indexOf(".desktop:")
        if (at < 0)
            continue
        var file = lines[i].substring(0, at + ".desktop".length)
        var rest = lines[i].substring(at + ".desktop:".length)
        if (!found[file]) {
            found[file] = { name: "", url: "", dir: file.substring(0, file.lastIndexOf("/")) }
            order.push(file)
        }
        if (rest.indexOf("Name=") === 0)
            found[file].name = trimTrailer(rest.substring("Name=".length))
        else if (rest.indexOf("URL=") === 0)
            found[file].url = rest.substring("URL=".length).trim()
    }
    var out = []
    for (var k = 0; k < order.length; k++) {
        var t = found[order[k]]
        if (t.name === "" || t.url === "")
            continue
        var source = t.url.charAt(0) === "/" ? t.url : t.dir + "/" + t.url
        out.push({ label: t.name, name: "New File" + extensionOf(t.url), from: source })
    }
    out.sort(function (a, b) { return a.label.localeCompare(b.label) })
    return out
}

// The shipped names end "LibreOffice Writer  ..." because the dialog that reads them appends the
// filename prompt; the ellipsis is that dialog's, not part of the name.
function trimTrailer(value) {
    return String(value).replace(/[\s.]+$/, "")
}

// The template's own suffix, so a Writer document is created as .odt and opens in Writer. A source
// with no dot in its last segment contributes none, rather than taking the directory's.
function extensionOf(url) {
    var leaf = String(url).split("/").pop()
    var dot = leaf.lastIndexOf(".")
    return dot > 0 ? leaf.substring(dot) : ""
}

// The whole flyout: the three built-ins, then whatever the desktop ships.
function entries(templates) {
    var out = []
    for (var i = 0; i < BUILTIN.length; i++)
        out.push({ id: entryId(BUILTIN[i].name, BUILTIN[i].from), label: BUILTIN[i].label })
    for (var j = 0; j < templates.length; j++)
        out.push({ id: entryId(templates[j].name, templates[j].from), label: templates[j].label })
    return out
}
