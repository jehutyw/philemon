.pragma library

.import "Format.js" as Format

// The Properties panel's table. Every value comes off the row the listing already holds, so the
// panel opens on what is in hand and asks the backend for nothing: name, size, mtime and st_mode
// are all in the rows reply, and the Kind is its envelope's own table.

// A row whose stat failed sends s, m and p all 0, and p is what says so, because a real st_mode
// always carries its file-type bits; see docs/protocol.md "rows". Those three are then unreadable
// and the panel says so rather than drawing 0 bytes and the epoch.
var UNREADABLE = "unknown"

function statFailed(row) {
    return !row || row.p === 0 || row.p === undefined
}

// The one place the panel's full path is built. A directory listing joins with a separator except
// at the root, where the base already ends in one; ui/Pane.qml's own join follows the same rule.
function fullPath(dir, name) {
    var base = String(dir || "")
    return base === "/" ? "/" + name : base + "/" + name
}

// kinds is the rows envelope's table and k the row's index into it, which is how a listing sends
// one "Plain text document" for the eight hundred rows that share it.
function kindOf(row, kinds) {
    if (!row || !kinds || row.k === undefined)
        return ""
    var name = kinds[row.k]
    return name === undefined ? "" : String(name)
}

function rows(row, kinds, dir, nowMs) {
    if (!row)
        return []
    var out = []
    out.push({ label: "Name", value: String(row.n) })
    out.push({ label: "Where", value: fullPath(dir, row.n) })
    var kind = kindOf(row, kinds)
    if (kind !== "")
        out.push({ label: "Type", value: kind })
    // A directory's own size is its inode's, not what it holds, so it is not offered as one: a
    // recursive figure is the dirsize walk's answer and this panel never starts one.
    if (!row.d)
        out.push({ label: "Size", value: statFailed(row) ? UNREADABLE : Format.size(row.s) })
    out.push({ label: "Modified", value: statFailed(row) ? UNREADABLE : Format.date(row.m, nowMs) })
    out.push({ label: "Permissions",
               value: statFailed(row) ? UNREADABLE : Format.permissions(row.p) })
    // Only a symlink row carries l, and it is the link's own bytes, so a relative target stays
    // relative: resolving it here would claim a destination the link does not name.
    if (row.l !== undefined && String(row.l) !== "")
        out.push({ label: "Points at", value: String(row.l) })
    return out
}
