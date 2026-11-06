// The generated palette, as the settings window watches it.
//
// A scheme or contrast change rewrites the palette file; the window reads it
// again and only repaints when the document really changed. `read` rejects a
// partial file, so a write caught halfway never blanks the window.
.pragma library

function read(text) {
    try {
        var data = JSON.parse(text)
        if (!data || typeof data !== "object" || Array.isArray(data))
            return null
        return data
    } catch (error) {
        return null
    }
}

function canonical(value) {
    if (Array.isArray(value))
        return value.map(canonical)
    if (value && typeof value === "object") {
        var out = {}
        Object.keys(value).sort().forEach(function (key) {
            out[key] = canonical(value[key])
        })
        return out
    }
    return value
}

function same(left, right) {
    return JSON.stringify(canonical(left)) === JSON.stringify(canonical(right))
}

function changed(current, text) {
    var next = read(text)
    return next !== null && !same(current, next)
}
