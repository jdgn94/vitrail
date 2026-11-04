// cava's frame numbers for the audio visualiser. No QML type is touched here:
// `tests/qml/tst_visualiser.qml` feeds it plain strings, arrays and documents.
.pragma library

var MAX_RANGE = 100

// One cava value: a number on the 0..100 scale, never negative or out of
// range; anything unreadable is silence.
function number(value) {
    var numeric = Number(value)
    if (isNaN(numeric) || !isFinite(numeric) || numeric < 0)
        return 0
    return Math.min(MAX_RANGE, numeric)
}

function listOf(source) {
    if (source === undefined || source === null)
        return []
    if (typeof source === "string")
        return source.split(/[;,\s]+/)
    if (Object.prototype.hasOwnProperty.call(source, "values"))
        return source.values
    if (source.length !== undefined)
        return source
    return []
}

// Exactly `count` values: a short frame is padded with silence and a long one
// is cut, so every bar always has a number.
function values(source, count) {
    var list = listOf(source)
    var total = Math.max(1, Math.floor(count || 0))
    var out = []
    for (var i = 0; i < total; i++)
        out.push(number(list[i]))
    return out
}

// A value as a 0..1 bar height.
function level(value) {
    return number(value) / MAX_RANGE
}
