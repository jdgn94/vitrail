// Reading `.desktop` files without the shell's own index.
//
// Quickshell keeps a list of desktop entries, but the launcher re-scans the
// application folders when it opens so an app installed while the shell was
// running shows up without a restart. Tested in
// tests/qml/tst_launcher_desktop.qml.
.pragma library

// One file's text as an entry with the fields the launcher reads.
function parse(text, id) {
    var out = {
        id: id, name: "", genericName: "", comment: "", icon: "", execString: "",
        keywords: [], categories: [], actions: [], noDisplay: false, terminal: false
    }
    var section = ""
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line === "" || line[0] === "#")
            continue
        if (line[0] === "[" && line[line.length - 1] === "]") {
            section = line.slice(1, -1)
            continue
        }
        if (section !== "Desktop Entry")
            continue
        var at = line.indexOf("=")
        if (at <= 0)
            continue
        var key = line.slice(0, at).trim()
        var value = line.slice(at + 1).trim()
        if (key === "Name")
            out.name = value
        else if (key === "GenericName")
            out.genericName = value
        else if (key === "Comment")
            out.comment = value
        else if (key === "Icon")
            out.icon = value
        else if (key === "Exec")
            out.execString = value
        else if (key === "Keywords")
            out.keywords = value.split(";").filter(function (word) { return word !== "" })
        else if (key === "Categories")
            out.categories = value.split(";").filter(function (word) { return word !== "" })
        else if (key === "Actions")
            out.actions = value.split(";").filter(function (word) { return word !== "" })
        else if (key === "NoDisplay")
            out.noDisplay = value === "true"
        else if (key === "Terminal")
            out.terminal = value === "true"
    }
    return out
}

// The `@@FILE path` + text blocks of a scan as entries.
function parseScan(output) {
    var out = []
    var path = null
    var text = ""
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i]
        if (line.indexOf("@@FILE ") === 0) {
            if (path !== null)
                out.push(parse(text, path.slice(path.lastIndexOf("/") + 1)))
            path = line.slice(7).trim()
            text = ""
        } else if (path !== null) {
            text += line + "\n"
        }
    }
    if (path !== null)
        out.push(parse(text, path.slice(path.lastIndexOf("/") + 1)))
    return out
}

// The scanned entries the shell's list does not know yet.
function missing(scanned, known) {
    var ids = ({})
    for (var i = 0; i < known.length; i++)
        ids[known[i].id] = true
    return scanned.filter(function (entry) {
        return entry.name !== "" && !ids[entry.id]
    })
}

// An Exec line without its field codes, ready for a shell.
function command(execString) {
    return String(execString || "").replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim()
}
