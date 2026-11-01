// The quick notes: one JSON array of strings on a single line, newest first.
// A line is what the bar's preference reader understands, so the notes travel
// as JSON inside one value. Pure rules, tested in tests/qml/tst_quick_notes.qml.
.pragma library

// How many notes the panel keeps; the oldest falls off.
var LIMIT = 20

// The stored value as a list. Anything that is not an array of strings reads
// as empty, so a hand-edited file never breaks the panel.
function parse(text) {
    var value = String(text || "").trim()
    if (value === "")
        return []
    try {
        var list = JSON.parse(value)
        if (!Array.isArray(list))
            return []
        return list.filter(function (note) { return typeof note === "string" && note !== "" })
    } catch (error) {
        return []
    }
}

function store(list) {
    return JSON.stringify(list)
}

// `text` with `note` at the top. A blank note changes nothing; a note already
// there moves up instead of repeating; the list stays within LIMIT.
function add(text, note) {
    var value = String(note || "").trim()
    if (value === "")
        return String(text || "")
    var list = parse(text).filter(function (line) { return line !== value })
    list.unshift(value)
    return store(list.slice(0, LIMIT))
}

// `text` without the line at `index`; an index out of range changes nothing.
function remove(text, index) {
    var list = parse(text)
    if (index < 0 || index >= list.length)
        return String(text || "")
    list.splice(index, 1)
    return store(list)
}

// What the widget lists: the first `count` notes, newest first.
function shown(text, count) {
    return parse(text).slice(0, Math.max(0, count))
}
