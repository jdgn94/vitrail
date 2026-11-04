.pragma library

// The bar's per-monitor overrides: one JSON object in bar.ini (`barMonitors`),
// keyed by Hyprland output name:
//
//     { "DP-1": { "edge": "top", "style": "floating" } }
//
// Only the edge and the style may differ per monitor; the bar's thickness
// stays global. An output without an entry, or a document that is not valid
// JSON, follows the global preferences.
var FIELDS = ["edge", "style"]

// The override document from preference text (or an already parsed object).
// Anything that is not an object is empty.
function document(text) {
    var doc = text
    if (typeof text === "string") {
        try {
            doc = JSON.parse(text)
        } catch (error) {
            doc = null
        }
    }
    return doc && typeof doc === "object" && !Array.isArray(doc) ? doc : {}
}

// The entry of one output, or null when it has no override.
function override(doc, name) {
    var entry = doc ? doc[name] : null
    return entry && typeof entry === "object" && !Array.isArray(entry) ? entry : null
}

// What one monitor's bar uses: the global defaults with the override's edge
// and style substituted. The defaults are never changed, and no key is
// invented.
function forMonitor(monitors, name, defaults) {
    var found = override(document(monitors), name)
    if (!found || !defaults || typeof defaults !== "object")
        return defaults
    var result = {}
    for (var key in defaults)
        result[key] = defaults[key]
    for (var i = 0; i < FIELDS.length; i++) {
        var field = FIELDS[i]
        if (Object.prototype.hasOwnProperty.call(found, field)
                && Object.prototype.hasOwnProperty.call(defaults, field)
                && typeof found[field] === "string")
            result[field] = found[field]
    }
    return result
}

// The new document text for one monitor's patch, or null when nothing
// changed. An empty value removes that field; an entry with no fields left
// drops the output altogether.
function update(text, name, patch) {
    var doc = document(text)
    var current = override(doc, name)
    var next = {}
    if (current) {
        for (var key in current)
            next[key] = current[key]
    }
    for (var field in patch) {
        var value = patch[field]
        if (value === null || value === undefined || value === "")
            delete next[field]
        else
            next[field] = value
    }
    if (Object.keys(next).length === 0) {
        if (!current)
            return null
        delete doc[name]
    } else if (current && JSON.stringify(current) === JSON.stringify(next)) {
        return null
    } else {
        doc[name] = next
    }
    return JSON.stringify(doc)
}
