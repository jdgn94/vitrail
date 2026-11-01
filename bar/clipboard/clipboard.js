// The clipboard panel's rules: what a preview is, what the search keeps and
// where the card sits next to the pointer. Tested in tests/qml/tst_clipboard.qml.
.pragma library

// "[[ binary data 120 KiB png 686x486 ]]" → { format, width, height }; text
// and anything else → null.
function imageOf(preview) {
    var match = /^\[\[ binary data .*? ([a-z0-9]+) (\d+)x(\d+) \]\]$/.exec(String(preview || "").trim())
    if (!match)
        return null
    return { format: match[1], width: Number(match[2]), height: Number(match[3]) }
}

// What an entry is: an image (cliphist says so in its preview), a link or
// plain text.
function kind(entry) {
    if (imageOf(entry ? entry.preview : ""))
        return "image"
    if (/^https?:\/\/\S+$/i.test(String((entry && entry.preview) || "").trim()))
        return "link"
    return "text"
}

// The entries of one kind whose preview contains the query, ignoring case; a
// blank query and "all" keep every kind.
function filter(entries, query, wantedKind) {
    var text = String(query || "").trim().toLowerCase()
    var wanted = String(wantedKind || "all")
    return entries.filter(function (entry) {
        if (wanted !== "all" && kind(entry) !== wanted)
            return false
        return text === "" || String(entry.preview || "").toLowerCase().indexOf(text) >= 0
    })
}

// The list without repeated copies: the newest of each preview wins.
function unique(entries) {
    var seen = {}
    var out = []
    for (var i = 0; i < entries.length; i++) {
        var key = String(entries[i].preview || "")
        if (seen[key])
            continue
        seen[key] = true
        out.push(entries[i])
    }
    return out
}

// How many entries of each kind, for the filter pills.
function counts(entries) {
    var out = { all: entries.length, text: 0, image: 0, link: 0 }
    for (var i = 0; i < entries.length; i++)
        out[kind(entries[i])] += 1
    return out
}

// One line for the row: the text with its whitespace collapsed, or the image
// and its size.
function label(entry) {
    var image = imageOf(entry ? entry.preview : "")
    if (image)
        return image.format.toUpperCase() + " · " + image.width + "×" + image.height
    return String((entry && entry.preview) || "").replace(/\s+/g, " ").trim()
}

// Where the card goes: at the pointer, pulled inside the screen by `margin`.
function clamp(x, y, width, height, screenWidth, screenHeight, margin) {
    var pad = Number(margin) || 0
    return {
        x: Math.max(pad, Math.min(Number(x) || 0, screenWidth - width - pad)),
        y: Math.max(pad, Math.min(Number(y) || 0, screenHeight - height - pad))
    }
}
