.import "../../ui/js/Palette.js" as Palette

// Lines of the live vernier colors.toml, verbatim, so the suite parses what the box parses.
var VERNIER = "# Vernier: the surface ladder, measured and regularised.\n"
    + "\n"
    + "mode = \"dark\"\n"
    + "accent = \"#b38956\"\n"
    + "selection = \"#31363a\"   # the selection highlight; foreground on it is 7.56:1\n"
    + "dark_background    = \"#0e1112\"   # chrome: bar, sidebars\n"
    + "background         = \"#14181a\"   # canvas: terminal, app bodies\n"
    + "cyan    = \"#27a6a2\"\n"
    + "hyprland_inactive_border = \"rgb(1b1f21)\"\n"

// Theme.applyColors reads isPalette as "the file was there and it meant something", and only that.
function run(check) {
    check("no file at all is not a palette", Palette.isPalette(Palette.parse("")), false)
    check("an unreadable file reads as no palette", Palette.isPalette(Palette.parse(undefined)), false)
    check("comments and blank lines alone are not a palette",
          Palette.isPalette(Palette.parse("# Vernier\n\n   \n")), false)
    check("a toml with no colour in it is not a palette",
          Palette.isPalette(Palette.parse("mode = \"dark\"\nname = \"vernier\"\n")), false)

    check("the live theme is a palette", Palette.isPalette(Palette.parse(VERNIER)), true)
    // Not stricter than the truth: a theme that sets one role is still a parsed theme.
    check("one colour is already a palette",
          Palette.isPalette(Palette.parse("accent = \"#b38956\"\n")), true)
    check("a palette naming no role Philemon models is still a palette",
          Palette.isPalette(Palette.parse("wallpaper_tint = \"#1b1f21\"\n")), true)

    var live = Palette.parse(VERNIER)
    check("the live fixture yields five colours", Object.keys(live).length, 5)
    check("dark_background is the surface role",
          Palette.pick(live, ["dark_background", "selection"], "#181825"), "#0e1112")
    check("cyan is the symlink role", Palette.pick(live, ["cyan", "color6"], "#94e2d5"), "#27a6a2")
    // green is in the real file but not in this fixture, which is the per-role fallback pick() owns.
    check("a role the body never set keeps its fallback",
          Palette.pick(live, ["green", "color2"], "#a6e3a1"), "#a6e3a1")
    check("an rgb() value is not a hex colour and is skipped",
          live["hyprland_inactive_border"], undefined)
}
