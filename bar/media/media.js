// Player labels and geometry: pure, tested in tests/qml/tst_media.qml.
.pragma library

// 3:07, or 1:02:03 when it runs past an hour. Negative or unknown is 0:00.
function clock(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0))
    var hours = Math.floor(total / 3600)
    var minutes = Math.floor((total % 3600) / 60)
    var rest = total % 60
    var tail = (rest < 10 ? "0" : "") + rest
    if (hours > 0)
        return hours + ":" + (minutes < 10 ? "0" : "") + minutes + ":" + tail
    return minutes + ":" + tail
}

// Browsers publish their MPRIS titles HTML-escaped: `&quot;`, `&amp;` and the
// numeric forms come back as the characters they mean.
function decode(text) {
    return String(text || "")
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'")
        .replace(/&#39;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&amp;/g, "&")
        .replace(/&#(\d+);/g, function (match, code) { return String.fromCharCode(Number(code)) })
}

// "Title — Artist", falling back to whichever exists, then to the player name.
function label(metadata, identity) {
    // Quickshell hands the raw MPRIS map, whose keys carry their namespace;
    // plain objects are accepted too, for the tests and other callers.
    var title = metadata ? String(metadata.title || metadata["xesam:title"] || "") : ""
    var artist = metadata ? String(metadata.artist || metadata["xesam:artist"] || "") : ""
    title = decode(title)
    artist = decode(artist)
    if (title && artist)
        return title + " — " + artist
    if (title)
        return title
    if (artist)
        return artist
    return identity ? String(identity) : ""
}

// The glyph of the button for the current state.
function glyph(playing) {
    return playing ? "pause" : "play_arrow"
}

function isPlaying(state) {
    return state === 1 || state === "playing"
}

// Where one mark of the disc's ring is in its bounce, 0..1: each mark is
// offset by the golden ratio from the one before.
function beat(phase, index) {
    return Math.abs(Math.sin(Math.PI * ((Number(phase) || 0) + (index * 0.618034) % 1)))
}

// A mark's length: `dot` (a round dot) when the ring is at rest, growing to
// `longest` at the top of its bounce as `energy` (0 paused .. 1 playing) rises.
function markLength(beatValue, energy, dot, longest) {
    return dot + (longest - dot) * beatValue * energy
}

// Its opacity: `idle` at rest, `low`..1 following the bounce while playing.
function markOpacity(beatValue, energy, idle, low) {
    return idle + (low + (1 - low) * beatValue - idle) * energy
}
