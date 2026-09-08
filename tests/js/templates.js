.import "../../ui/js/Templates.js" as Templates

// The XDG template locations, as this box ships them. Captured from
// `grep -H -E '^(Name|URL)=' -r --include=*.desktop /usr/share/templates ~/Templates`, 2026-09-07.
function run(check) {
    var scan = "/usr/share/templates/soffice.odt.desktop:Name=LibreOffice Writer  ...\n"
             + "/usr/share/templates/soffice.odt.desktop:URL=.source/soffice.odt\n"
             + "/usr/share/templates/soffice.ods.desktop:Name=LibreOffice Calc  ...\n"
             + "/usr/share/templates/soffice.ods.desktop:URL=.source/soffice.ods\n"
             + "/usr/share/templates/soffice.odt.desktop:Name[de]=LibreOffice Writer  ...\n"

    var found = Templates.parse(scan)
    check("both shipped templates are found", found.length, 2)
    // Sorted, so Calc leads Writer whatever order grep walked the directory in.
    check("the flyout is ordered by name, not by readdir", found[0].label, "LibreOffice Calc")
    // The shipped names carry the file dialog's own ellipsis; it is not part of the name.
    check("the trailing ellipsis is not part of the label", found[1].label, "LibreOffice Writer")
    check("the URL resolves against its own .desktop's directory",
          found[1].from, "/usr/share/templates/.source/soffice.odt")
    check("the new file takes the template's suffix, so it opens in the right program",
          found[1].name, "New File.odt")
    // Name[de]= is a translation, and matching it would have overwritten the name with the last one read.
    check("a localised name is not the name", found[1].label.indexOf("[de]"), -1)

    check("no templates at all is not an error", Templates.parse("").length, 0)
    check("a line that is not a template is skipped", Templates.parse("garbage\n").length, 0)
    // A .desktop naming no URL points at nothing, and a row that creates nothing is not a row.
    check("an entry with no URL is dropped",
          Templates.parse("/a/x.desktop:Name=Orphan\n").length, 0)

    // The flyout itself: three built-ins first, then the desktop's own.
    var rows = Templates.entries(found)
    check("the three built-ins lead the flyout", rows.length, 5)
    check("and an empty file is the first of them", rows[0].label, "Empty file")
    check("a box with no templates still offers the three", Templates.entries([]).length, 3)

    // The id carries both halves through one submenu string; NUL is the one byte a path cannot hold.
    var round = Templates.split(rows[4].id)
    check("the id round-trips the name", round.name, "New File.odt")
    check("and the template it copies", round.from, "/usr/share/templates/.source/soffice.odt")
    var plain = Templates.split(Templates.entryId("New File.txt", ""))
    check("a built-in round-trips with no template", plain.name + "|" + plain.from, "New File.txt|")
}
