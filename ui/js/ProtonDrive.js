.pragma library

// The parsing half of ui/ProtonDrive.qml, kept here so every shape the CLI can hand back is
// checked without a window or a network call.

// Sample input, `proton-drive filesystem list -t folder -j /my-files`, trimmed to the read fields:
// [
// {"uid":"...","name":{"ok":true,"value":"Backups"},"type":"folder",...},
// {"uid":"...","name":{"ok":true,"value":"Media"},"type":"folder",...},
// ]
// The name arrives wrapped in an ok/value pair because a name that failed to decrypt has no value,
// and those are dropped rather than drawn as an entry nothing can be uploaded into.
function parseFolders(raw, root) {
    var out = [{ id: root, label: "My files" }]
    var text = String(raw || "").trim()
    if (text === "")
        return out
    var data
    try {
        data = JSON.parse(text)
    } catch (e) {
        return out
    }
    if (!data || typeof data.length !== "number")
        return out
    for (var i = 0; i < data.length; i++) {
        var node = data[i] || {}
        if (node.type !== "folder")
            continue
        var name = node.name && node.name.ok ? String(node.name.value || "") : ""
        if (name === "")
            continue
        out.push({ id: root + "/" + name, label: name })
    }
    return out
}

// Sample input, one frame of the CLI's own progress redraw with its escapes already stripped:
// "ℹ Uploaded 1 | Queued 2\n⠏ 52.43% holiday.mp4 (38.15 MiB)"
// Both halves are optional in any one frame, so each is read on its own and a frame carrying
// neither leaves the caller's last reading alone.
function parseProgress(chunk) {
    var text = String(chunk || "")
    var out = { percent: -1, done: -1, queued: -1 }
    var pct = /([0-9]+(?:\.[0-9]+)?)%/.exec(text)
    if (pct)
        out.percent = parseFloat(pct[1])
    var counts = /Uploaded ([0-9]+) \| Queued ([0-9]+)/.exec(text)
    if (counts) {
        out.done = parseInt(counts[1], 10)
        out.queued = parseInt(counts[2], 10)
    }
    return out
}

// The status bar's one line. The count leads because it is the part that never stalls: a large file
// can sit on one percentage for a while, and "2 of 5" still says the run is moving.
function progressText(done, total, percent) {
    var head = "Uploading to Proton Drive"
    if (total > 1)
        head = "Uploading " + Math.min(done + 1, total) + " of " + total + " to Proton Drive"
    return percent >= 0 ? head + " · " + Math.round(percent) + "%" : head
}
