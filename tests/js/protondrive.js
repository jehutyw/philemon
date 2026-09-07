.import "../../ui/js/ProtonDrive.js" as Drive

// The CLI's two machine-facing shapes: the folder listing the flyout is built from, and one frame
// of the progress redraw. Both are captured from the real tool, 2026-09-07.
function run(check) {
    var ROOT = "/my-files"

    // Trimmed to the fields parseFolders reads; the real entries carry twenty more.
    var listing = '[\n'
        + '{"uid":"a","name":{"ok":true,"value":"OliviaGunn.mp4"},"type":"file"},\n'
        + '{"uid":"b","name":{"ok":true,"value":"Backups"},"type":"folder"},\n'
        + '{"uid":"c","name":{"ok":true,"value":"Obsidian Vault"},"type":"folder"},\n'
        + '{"uid":"d","name":{"ok":false},"type":"folder"}\n'
        + ']'
    var folders = Drive.parseFolders(listing, ROOT)
    check("My files leads the flyout, so a plain upload needs no folder", folders[0].id, ROOT)
    check("and it is labelled, not shown as a path", folders[0].label, "My files")
    check("a folder becomes an entry under it", folders[1].id, ROOT + "/Backups")
    check("a space in the name is carried, not escaped", folders[2].id, ROOT + "/Obsidian Vault")
    check("files are not destinations", folders.length, 3)
    // A name that failed to decrypt has no value, and a path built from "" would upload to the root
    // while claiming to be a folder.
    check("an undecryptable name is dropped rather than guessed",
          folders.map(function (f) { return f.label }).join("|"), "My files|Backups|Obsidian Vault")

    check("a logged-out box still offers My files", Drive.parseFolders("", ROOT).length, 1)
    check("garbage is not a listing", Drive.parseFolders("not json", ROOT).length, 1)
    check("an object where a list belongs is not a listing", Drive.parseFolders('{"a":1}', ROOT).length, 1)

    // One frame, escapes already stripped by the caller.
    var frame = "ℹ Uploaded 1 | Queued 2\n⠏ 52.43% holiday.mp4 (38.15 MiB)"
    var at = Drive.parseProgress(frame)
    check("the percentage is read off the frame", at.percent, 52.43)
    check("so is the finished count", at.done, 1)
    check("and the queue behind it", at.queued, 2)

    // Either half can be missing from a frame; a reading of -1 tells the caller to keep the last.
    check("a frame with only a count carries no percentage",
          Drive.parseProgress("ℹ Uploaded 3 | Queued 0").percent, -1)
    check("a frame with only a percentage carries no count",
          Drive.parseProgress("⠏ 7.00% a.bin (1 MiB)").done, -1)
    check("a whole number percentage still reads", Drive.parseProgress("100% a.bin").percent, 100)
    check("an empty frame reads as nothing at all",
          Drive.parseProgress("").percent + "|" + Drive.parseProgress("").done, "-1|-1")

    // The status bar line. One file needs no count in front of it.
    check("a single file names no count", Drive.progressText(0, 1, 52.4),
          "Uploading to Proton Drive · 52%")
    check("several files count as they go", Drive.progressText(1, 5, 52.4),
          "Uploading 2 of 5 to Proton Drive · 52%")
    check("no reading yet and the line still says what is happening",
          Drive.progressText(0, 3, -1), "Uploading 1 of 3 to Proton Drive")
    // The CLI reports the finished count, so the last frame of a run has done === total; naming
    // "6 of 5" there would be the one moment the line is visibly wrong.
    check("the count never runs past the total", Drive.progressText(5, 5, 99),
          "Uploading 5 of 5 to Proton Drive · 99%")
}
