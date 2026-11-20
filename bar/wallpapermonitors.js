// The per-monitor wallpapers: one JSON document in wallpaper.ini keyed by
// Hyprland output name, {"DP-1": {"wallpaper": "/path"}}. An output without a
// picture follows the global one; the effect is global and applies to whichever
// picture the output shows. Keeping this pure makes it testable with
// qmltestrunner and shared by the settings window and the bar.
.pragma library

// A document from its text. Anything that is not an object is empty.
function parse(text) {
    var doc
    try {
        doc = JSON.parse(text)
    } catch (error) {
        doc = null
    }
    return doc && typeof doc === "object" && !Array.isArray(doc) ? doc : {}
}

function stringify(doc) {
    return JSON.stringify(doc)
}

function copy(value) {
    return JSON.parse(JSON.stringify(value))
}

// One output's entry, with its picture always readable.
function of(text, output) {
    var entry = parse(text)[output]
    if (!entry || typeof entry !== "object")
        return { wallpaper: "" }
    return { wallpaper: typeof entry.wallpaper === "string" ? entry.wallpaper : "" }
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b)
}

// The new document text for one patch, or null when nothing changed. An entry
// without a picture is dropped: it follows the global one. A leftover key from
// an older document (a per-output effect) goes with it.
function update(text, output, patch) {
    var doc = parse(text)
    var base = doc[output] && typeof doc[output] === "object" ? copy(doc[output]) : { wallpaper: "" }
    var next = { wallpaper: typeof base.wallpaper === "string" ? base.wallpaper : "" }
    for (var key in patch)
        next[key] = patch[key]
    if (next.wallpaper === "") {
        if (!doc[output])
            return null
        delete doc[output]
        return stringify(doc)
    }
    if (same(base, next))
        return null
    doc[output] = next
    return stringify(doc)
}

// The new text without that output, or null when it had no entry.
function remove(text, output) {
    var doc = parse(text)
    if (!doc[output])
        return null
    delete doc[output]
    return stringify(doc)
}
