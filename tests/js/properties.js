.import "../../ui/js/Properties.js" as Properties

// The rows reply's own shape, from docs/protocol.md "rows": n, d, s, m, p, i, t, k, and l on a
// symlink alone. Every value the panel draws comes off one of those, so it opens with no request.
function run(check) {
    var kinds = ["Plain text document", "Folder"]
    var file = { n: "notes.txt", d: false, s: 12, m: 1787790423, p: 33188, i: "text-x-generic",
                 t: false, k: 0 }

    var rows = Properties.rows(file, kinds, "/home/jehuty/Documents", 1787790500000)
    function value(label) {
        for (var i = 0; i < rows.length; i++)
            if (rows[i].label === label)
                return rows[i].value
        return null
    }
    check("the panel names the file", value("Name"), "notes.txt")
    // The whole point of the row: the listing shows a leaf, and this is the only place the path is.
    check("and states the full path, not the leaf", value("Where"), "/home/jehuty/Documents/notes.txt")
    check("the Kind comes off the envelope's table, not the extension", value("Type"), "Plain text document")
    check("the size is formatted, not raw bytes", value("Size"), "12 B")
    // The nine bits with no file-type character, which is the form the preview column already draws.
    check("the mode is drawn as permissions", value("Permissions"), "rw-r--r--")
    check("a file that is not a link points at nothing", value("Points at"), null)

    // The root is the one directory whose own path already ends in a separator.
    check("a file at the root does not gain a double separator",
          Properties.fullPath("/", "vmlinuz"), "/vmlinuz")

    // A directory's own size is its inode's and not what it holds, so the panel offers no figure
    // rather than one that reads as 4 KB for a folder holding twenty gigabytes.
    var dir = { n: "photos", d: true, s: 4096, m: 1787790424, p: 16877, k: 1, v: 56 }
    var dirRows = Properties.rows(dir, kinds, "/home/jehuty", 1787790500000)
    check("a folder is offered no size", dirRows.filter(function (r) { return r.label === "Size" }).length, 0)
    check("but it still states its type", dirRows[2].value, "Folder")

    // A stat that failed sends s, m and p all 0, and p is what says so; drawing those would claim
    // the file is empty and was modified at the epoch, which are two statements it cannot make.
    var broken = { n: "gone", d: false, s: 0, m: 0, p: 0, k: 0 }
    var brokenRows = Properties.rows(broken, kinds, "/tmp", 1787790500000)
    function brokenValue(label) {
        for (var j = 0; j < brokenRows.length; j++)
            if (brokenRows[j].label === label)
                return brokenRows[j].value
        return null
    }
    check("an unreadable stat does not report zero bytes", brokenValue("Size"), "unknown")
    check("nor the epoch as a date", brokenValue("Modified"), "unknown")
    check("nor a mode it never read", brokenValue("Permissions"), "unknown")
    // The name and the path are the client's own, so they survive a stat that failed entirely.
    check("the name and path still stand", brokenValue("Where"), "/tmp/gone")

    // l is the link's own bytes, so a relative target stays relative: resolving it here would name
    // a destination the link does not.
    var link = { n: "latest", d: false, s: 7, m: 1787790423, p: 41471, k: 0, l: "../builds/9" }
    check("a symlink states where it points, verbatim",
          Properties.rows(link, kinds, "/srv", 1787790500000).pop().value, "../builds/9")

    check("no row at all is an empty table, never a throw", Properties.rows(null, kinds, "/", 0).length, 0)
}
