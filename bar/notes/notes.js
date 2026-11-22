// The quick notes: one JSON array of strings, newest first, on a single line.
// A line is what the bar's preference reader understands, so the notes travel
// as JSON inside one value. A note may also be stored as `{ text, at }`, where
// `at` is when it was added (epoch ms), so the bar element can show its age;
// the older plain-string form keeps working. Pure rules, tested in
// tests/qml/tst_quick_notes.qml and tests/qml/tst_notesbar.qml.
.pragma library

// How many notes the store keeps; the oldest falls off.
var LIMIT = 20

// The stored value as a list of `{ text, at }`; `at` is 0 for a note written
// before the age was kept. Anything that is not an array reads as empty, so a
// hand-edited file never breaks the panel.
function entries(text) {
    var value = String(text || "").trim()
    if (value === "")
        return []
    var list = null
    try {
        list = JSON.parse(value)
    } catch (error) {
        return []
    }
    if (!Array.isArray(list))
        return []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var item = list[i]
        if (typeof item === "string") {
            if (item !== "")
                out.push({ text: item, at: 0 })
        } else if (item && typeof item === "object" && typeof item.text === "string"
                   && item.text !== "") {
            var at = Number(item.at)
            out.push({ text: item.text, at: isFinite(at) && at > 0 ? at : 0 })
        }
    }
    return out
}

// The stored value as a list of strings.
function parse(text) {
    return entries(text).map(function (entry) { return entry.text })
}

// The notes as the one-line preference value. A note without an age stays a
// plain string, exactly as the notification panel has always written it.
function store(list) {
    var out = []
    for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (entry.at > 0)
            out.push({ text: entry.text, at: entry.at })
        else
            out.push(entry.text)
    }
    return JSON.stringify(out)
}

// `text` with `note` at the top. A blank note changes nothing; a note already
// there moves up instead of repeating; the list stays within LIMIT. `now` is
// optional: when given (the bar element), the note keeps its age.
function add(text, note, now) {
    var value = String(note || "").trim()
    if (value === "")
        return String(text || "")
    var list = entries(text).filter(function (entry) { return entry.text !== value })
    var at = Number(now)
    list.unshift({ text: value, at: isFinite(at) && at > 0 ? Math.round(at) : 0 })
    return store(list.slice(0, LIMIT))
}

// `text` without the note at `index`; an index out of range changes nothing.
function remove(text, index) {
    var list = entries(text)
    if (index < 0 || index >= list.length)
        return String(text || "")
    list.splice(index, 1)
    return store(list)
}

// What the widget lists: the first `count` notes, newest first.
function shown(text, count) {
    return parse(text).slice(0, Math.max(0, count))
}
