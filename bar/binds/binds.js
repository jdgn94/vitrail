// The cheatsheet's pure half: filtering, readable descriptions and the state
// parser. No QML types, so the tests exercise it without a window.
.pragma library

// Everything a search may match: the combo, the description and the command.
function haystack(row) {
    return [row.mods, row.key, row.description, row.dispatcher, row.arg]
        .join(" ").toLowerCase()
}

// Every word of the query must appear somewhere (order does not matter).
function filter(rows, query) {
    var text = String(query || "").trim().toLowerCase()
    if (text === "")
        return rows
    var terms = text.split(/\s+/)
    var out = []
    for (var i = 0; i < rows.length; i++) {
        var line = haystack(rows[i])
        var found = true
        for (var j = 0; j < terms.length; j++) {
            if (line.indexOf(terms[j]) < 0) {
                found = false
                break
            }
        }
        if (found)
            out.push(rows[i])
    }
    return out
}

// "Super+Shift" + "←" as one shortcut.
function combo(row) {
    return row.mods ? row.mods + "+" + row.key : row.key
}

// "panel-overlay" -> "Panel Overlay".
function title(text) {
    var words = String(text || "").replace(/[-_]/g, " ").split(/\s+/)
    var out = []
    for (var i = 0; i < words.length; i++) {
        var word = words[i]
        if (word !== "")
            out.push(word.charAt(0).toUpperCase() + word.slice(1))
    }
    return out.join(" ")
}

// A Hyprland description ("window/close") as a readable line. Known groups
// are translated; an unknown one keeps its own words.
function label(row, t) {
    var text = String(row.description || row.dispatcher || "")
    var slash = text.indexOf("/")
    if (slash <= 0)
        return text
    var group = text.slice(0, slash)
    var key = "binds.group." + group
    var known = t ? t(key) : key
    if (known === key)
        known = title(group)
    return known + " · " + title(text.slice(slash + 1))
}

// `python3 -m vitrail.binds state`, or a broken answer, as the host expects.
function parseState(text) {
    try {
        var data = JSON.parse(text)
        if (!data || data.available === false)
            return { available: false, rows: [] }
        return { available: true, rows: Array.isArray(data.rows) ? data.rows : [] }
    } catch (error) {
        return { available: false, rows: [] }
    }
}
