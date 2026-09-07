.pragma library

// Read only Obsidian's registered vault paths; never walk or index their contents.
function vaults(text) {
    var data
    try { data = JSON.parse(text).vaults } catch (_) { return [] }
    if (!data || typeof data !== "object" || Array.isArray(data)) return []
    var out = [], seen = Object.create(null)
    Object.keys(data).forEach(function (id) {
        var item = data[id]
        if (!item || typeof item.path !== "string" || item.path[0] !== "/") return
        var path = item.path.replace(/\/+$/, "")
        if (!path || seen[path]) return
        seen[path] = true
        out.push({ path: path, label: path.substring(path.lastIndexOf("/") + 1) + " (Obsidian)",
                   group: "favorite", kind: "favorite", glyph: "file-text" })
    })
    return out.sort(function (a, b) { return a.path < b.path ? -1 : a.path > b.path ? 1 : 0 })
}

function favorites(existing, vaults) {
    return existing.concat(vaults.filter(function (v) {
        return !existing.some(function (e) { return e.path === v.path })
    }))
}

function isNote(path, vaults) {
    if (!/\.md$/i.test(path)) return false
    return vaults.some(function (v) {
        if (path.indexOf(v.path + "/") !== 0) return false
        var parts = path.substring(v.path.length + 1).split("/")
        return parts.every(function (p) { return p !== ".." && p !== ".obsidian" })
    })
}
