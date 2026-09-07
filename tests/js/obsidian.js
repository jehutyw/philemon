.import "../../ui/js/Obsidian.js" as Obsidian
.import "../../ui/js/Menu.js" as Menu

function run(check) {
    var vaults = Obsidian.vaults(JSON.stringify({ vaults: {
        first: { path: "/notes/Work/" }, duplicate: { path: "/notes/Work" },
        second: { path: "/notes/Personal" }, invalid: { path: "relative" }, empty: null
    }}))
    check("registry validates and deduplicates", vaults.length, 2)
    check("stable shortcut label", vaults[0].label, "Personal (Obsidian)")
    check("broken registry is optional", Obsidian.vaults("bad").length, 0)
    check("null registry is optional", Obsidian.vaults("null").length, 0)
    check("no duplicate existing bookmark", Obsidian.favorites([{path: "/notes/Work"}], vaults).length, 2)
    check("nested note", Obsidian.isNote("/notes/Work/sub/Note.md", vaults), true)
    check("uppercase extension", Obsidian.isNote("/notes/Work/Note.MD", vaults), true)
    check("sibling is not vault", Obsidian.isNote("/notes/Work-old/Note.md", vaults), false)
    check("traversal is not note", Obsidian.isNote("/notes/Work/../Note.md", vaults), false)
    check("plugin docs are not notes", Obsidian.isNote("/notes/Work/.obsidian/plugins/readme.md", vaults), false)
    check("attachment is not note", Obsidian.isNote("/notes/Work/photo.jpg", vaults), false)
    check("no registered vault", Obsidian.isNote("/notes/Work/a.md", []), false)
    var state = {hasRow: true, rowIsObsidianNote: true, archiveFormats: [], taildropPeers: [], dropboxPath: ""}
    function hasAction() { return Menu.listingEntries(state).some(function (e) { return e.action === "obsidian" }) }
    check("note menu exposes action", hasAction(), true)
    state.rowIsObsidianNote = false
    check("other files hide action", hasAction(), false)
    state.rowIsObsidianNote = true
    state.hasRow = false
    check("empty space hides action", hasAction(), false)
}
