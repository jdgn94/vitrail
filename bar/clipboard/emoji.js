// The emoji tab's rules: the nine Unicode groups, the search and the counts.
// Tested in tests/qml/tst_emoji.qml; the data is `assets/emoji.json`, built by
// scripts/build-emoji.py from emoji-test.txt and the CLDR annotations.
.pragma library

// Unicode's groups, in its order.
var GROUPS = [
    "Smileys & Emotion",
    "People & Body",
    "Animals & Nature",
    "Food & Drink",
    "Travel & Places",
    "Activities",
    "Objects",
    "Symbols",
    "Flags"
]

// The emojis whose words contain the query, inside `group` ("all" keeps every
// group). The words are already lower case and carry both languages.
function filter(entries, query, group) {
    var text = String(query || "").trim().toLowerCase()
    var wanted = String(group || "all")
    return entries.filter(function (entry) {
        if (wanted !== "all" && entry.g !== wanted)
            return false
        return text === "" || String(entry.k || "").indexOf(text) >= 0
    })
}

// How many emojis each group holds, for the category pills.
function counts(entries) {
    var out = { all: entries.length }
    for (var i = 0; i < entries.length; i++)
        out[entries[i].g] = (out[entries[i].g] || 0) + 1
    return out
}
