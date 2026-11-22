// The clipboard bar element's rules: the copies it shows, the redaction shared
// with the history, and the button's two lines. Tested in
// tests/qml/tst_clipboardbar.qml.
.pragma library
.import "../clipboard/clipboard.js" as Clipboard
.import "../clipboard/colors.js" as Colors

// The default number of copies the popup lists (the `clipboardbarRecent`
// preference is 1–10).
var DEFAULT = 5

// A colour is not a copy: the palette and the colour picker write colours to
// the clipboard, and those must not push a real copy out of the five. The
// colour tab's own reader knows hex; a copy that came out in RGB or HSL is
// still a colour.
var COLOR_FUNCTION = /^(?:rgb|rgba|hsl|hsla)\([^)]*\)$/i

function isColor(text) {
    var value = String(text || "").trim()
    return Colors.isColor(value) || COLOR_FUNCTION.test(value)
}

function copy(entry) {
    return !isColor(String((entry && entry.preview) || "").trim())
}

// The history's entries without the colours, newest first, each preview once.
function copies(entries) {
    return Clipboard.unique(Array.isArray(entries) ? entries : []).filter(copy)
}

// The newest `limit` copies; a missing or unreadable limit is the default.
function recent(entries, limit) {
    var count = Number(limit)
    if (!isFinite(count) || count < 1)
        count = DEFAULT
    return copies(entries).slice(0, Math.floor(count))
}

// How many copies the history holds, for the tooltip.
function count(entries) {
    return copies(entries).length
}

// One copy as one redacted line; the history shows the same label.
function label(entry) {
    return Clipboard.label(entry)
}

function newest(entries) {
    var list = copies(entries)
    return list.length > 0 ? label(list[0]) : ""
}

// The oldest copy the popup shows, or "" when it shows nothing.
function oldest(entries, limit) {
    var list = recent(entries, limit)
    return list.length > 0 ? label(list[list.length - 1]) : ""
}
