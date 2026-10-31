// Fuzzy matching, frecency and the final ranking of launcher items. An item
// is { id, fields: [{ text, weight }] }; usage is { score, last } per id.
.pragma library

var HALF_LIFE = 7 * 86400000
// How much the use of an item and its being a favourite add to a 0..1 match.
// Both stay under the gap between a prefix and a word match, so a clearly
// better match still wins.
var FRECENCY_WEIGHT = 0.12
var FAVOURITE_BOOST = 0.1
// Frecency at which the boost stops growing.
var FRECENCY_CAP = 20
var MIN_SCORE = 0.2

function normalize(text) {
    return String(text || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
}

// One word against one text, 0 (no match) to 1 (equal).
function scoreWord(word, text) {
    if (text === word)
        return 1
    if (text.indexOf(word) === 0)
        return 0.9
    var at = text.indexOf(word)
    if (at > 0) {
        var boundary = /[\s\-_.\/]/.test(text.charAt(at - 1))
        return boundary ? 0.8 : 0.6
    }
    // Letters in order, tighter is better: "frfx" in "firefox". Starting at
    // the start of a word, and not for a single letter.
    if (word.length < 2)
        return 0
    var start = text.indexOf(word.charAt(0))
    while (start > 0 && !/[\s\-_.\/]/.test(text.charAt(start - 1)))
        start = text.indexOf(word.charAt(0), start + 1)
    if (start < 0)
        return 0
    var from = start
    var first = start
    for (var i = 0; i < word.length; i++) {
        var found = text.indexOf(word.charAt(i), from)
        if (found < 0)
            return 0
        from = found + 1
    }
    var span = from - first
    // Letters scattered over a long text are not a match.
    if (span > word.length * 1.5 + 1)
        return 0
    return MIN_SCORE + 0.25 * (word.length / span)
}

// A query of several words: each must match, the score is their mean.
function score(query, text) {
    var words = normalize(query).split(/\s+/).filter(function (word) { return word !== "" })
    if (words.length === 0)
        return 0
    var haystack = normalize(text)
    var sum = 0
    for (var i = 0; i < words.length; i++) {
        var one = scoreWord(words[i], haystack)
        if (one === 0)
            return 0
        sum += one
    }
    return sum / words.length
}

// Several fields: each word takes the best weighted field; every word must
// match somewhere.
function scoreFields(query, fields) {
    var words = normalize(query).split(/\s+/).filter(function (word) { return word !== "" })
    if (words.length === 0)
        return 0
    var texts = fields.map(function (field) { return { text: normalize(field.text), weight: field.weight } })
    var sum = 0
    for (var i = 0; i < words.length; i++) {
        var best = 0
        for (var j = 0; j < texts.length; j++)
            best = Math.max(best, texts[j].weight * scoreWord(words[i], texts[j].text))
        if (best === 0)
            return 0
        sum += best
    }
    return sum / words.length
}

// --- usage -------------------------------------------------------------------

function frecency(entry, now) {
    if (!entry)
        return 0
    return entry.score * Math.pow(0.5, Math.max(0, now - entry.last) / HALF_LIFE)
}

// The entry after one more use at `now`.
function bump(entry, now) {
    return { score: frecency(entry, now) + 1, last: now }
}

function usageBoost(entry, favourite, now) {
    var value = Math.min(Math.log(1 + frecency(entry, now)) / Math.log(1 + FRECENCY_CAP), 1)
    return FRECENCY_WEIGHT * value + (favourite ? FAVOURITE_BOOST : 0)
}

// ctx: { history, favourites, now, limit }. -> [{ item, score }], best first.
function rank(items, query, ctx) {
    var ranked = []
    items.forEach(function (item) {
        var match = scoreFields(query, item.fields)
        if (match <= 0)
            return
        var boost = usageBoost(ctx.history[item.id], ctx.favourites.indexOf(item.id) >= 0, ctx.now)
        ranked.push({ item: item, score: match + boost, match: match })
    })
    ranked.sort(function (a, b) { return b.score - a.score })
    return ctx.limit ? ranked.slice(0, ctx.limit) : ranked
}

// Items that were used, most frecent first. ctx: { history, now, limit, skip }.
function recent(items, ctx) {
    var skip = ctx.skip || []
    return items.filter(function (item) {
        return ctx.history[item.id] !== undefined && skip.indexOf(item.id) < 0
    }).sort(function (a, b) {
        return frecency(ctx.history[b.id], ctx.now) - frecency(ctx.history[a.id], ctx.now)
    }).slice(0, ctx.limit)
}
