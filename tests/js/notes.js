.import "../../ui/js/Notes.js" as Notes

function run(check) {
    check("BOM and CRLF normalize for editing", Notes.source("\uFEFFa\r\nb\r\n"), "a\nb\n")
    var note = {path: "/Vault/A.md", original: "\uFEFFa\r\n", text: "a\n"}
    check("normalization is not a dirty edit", Notes.dirty(note), false)
    note.text += "b"
    check("dirty note label", Notes.label(note), "A.md *")
    check("wikilink alias", Notes.preview("[[Folder/Other|Alias]]"), "[Alias](philemon-note:Folder%2FOther)")
    check("link encoding passes to service", Notes.linkTarget("philemon-note:caf%C3%A9%20note"), "caf%C3%A9%20note")
    check("literal percent in wiki names survives backend decoding", Notes.linkTarget("philemon-note:100%2520percent"), "100%2520percent")
    check("Markdown links retained", Notes.preview("[Next](../Next.md)"), "[Next](../Next.md)")
    check("inline code unchanged", Notes.preview("`[[Code]]`"), "`[[Code]]`")
    check("fenced code unchanged", Notes.preview("```md\n[[Code]]\n```"), "```md\n[[Code]]\n```")
    check("HTML images cannot load", Notes.preview('<img src="https://example.org/x">'), '&lt;img src="https://example.org/x"&gt;')
    check("Markdown images cannot load", Notes.preview("![Alt](https://example.org/x)"), "`Image: Alt`")
    check("embeds stay textual", Notes.preview("![[Other]]"), "`Embed: Other`")
    check("reference images cannot load", Notes.preview("![Alt][reference]"), "`Image: Alt`[reference]")
}
