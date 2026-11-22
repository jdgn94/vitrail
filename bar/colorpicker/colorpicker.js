// The colour picker element's rules: how many recent colours it keeps and
// shows, and how a hex is written. The palette's `colors.js` still owns the
// parsing, the formats and the list; this file only bounds the picker's own
// store (24) and the preference (4–24). Tested in tests/qml/tst_colorpicker.qml.
.pragma library
.import "../clipboard/colors.js" as Colors

// The picker keeps and shows its colours through the same helpers the colour
// tab uses; the store is capped a little wider than the palette's ten.
var MAX = 24
var MIN = 4
var DEFAULT = 12

// The `colorpickerRecent` preference, clamped to what the store keeps.
function cap(value) {
    var number = value === undefined || value === null || String(value).trim() === ""
        ? NaN : Math.round(Number(value))
    if (!isFinite(number))
        return DEFAULT
    return Math.max(MIN, Math.min(MAX, number))
}

// The stored preference as a clean list, up to what the store keeps.
function stored(text) {
    return Colors.recentFrom(text, MAX)
}

// The colours the popup shows: the newest `limit` of the store.
function recent(text, limit) {
    return stored(text).slice(0, cap(limit))
}

// The list with `hex` at the top, without repeats, capped at `max` (24).
function add(list, hex, max) {
    var capAt = Math.max(MIN, Math.min(MAX, Math.round(Number(max)) || MAX))
    return Colors.addRecent(Array.isArray(list) ? list : stored(list), hex, capAt)
}

// A colour written the way the picker's rows and the clipboard write it.
function hex(text) {
    var color = Colors.parse(text)
    return color ? Colors.format(color, "hex") : ""
}
