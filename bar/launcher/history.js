// What the launcher remembers: launches (with frecency), favourites and hidden
// apps, as one small JSON document. Every function returns a new state.
.pragma library
.import "search.js" as Search

var VERSION = 1
// Entries kept; the least frecent go first.
var LIMIT = 200

function empty() {
    return { version: VERSION, history: {}, favourites: [], hidden: [], clearedAt: 0 }
}

function strings(value) {
    return Array.isArray(value) ? value.filter(function (item) { return typeof item === "string" }) : []
}

function parse(text) {
    var state = empty()
    try {
        var data = JSON.parse(text)
        if (!data || typeof data !== "object" || Array.isArray(data))
            return state
        state.favourites = strings(data.favourites)
        state.hidden = strings(data.hidden)
        state.clearedAt = Number(data.clearedAt) || 0
        if (data.history && typeof data.history === "object" && !Array.isArray(data.history)) {
            for (var id in data.history) {
                var entry = data.history[id]
                if (entry && Number(entry.score) > 0)
                    state.history[id] = { score: Number(entry.score), last: Number(entry.last) || 0 }
            }
        }
    } catch (error) {
    }
    return state
}

function serialize(state) {
    return JSON.stringify(state)
}

function copy(state) {
    return {
        version: VERSION, history: Object.assign({}, state.history), favourites: state.favourites.slice(),
        hidden: state.hidden.slice(), clearedAt: state.clearedAt
    }
}

function record(state, id, now) {
    var next = copy(state)
    next.history[id] = Search.bump(next.history[id], now)
    var ids = Object.keys(next.history)
    if (ids.length > LIMIT) {
        ids.sort(function (a, b) {
            return Search.frecency(next.history[b], now) - Search.frecency(next.history[a], now)
        })
        ids.slice(LIMIT).forEach(function (drop) { delete next.history[drop] })
    }
    return next
}

function isPinned(state, id) {
    return state.favourites.indexOf(id) >= 0
}

function togglePin(state, id) {
    var next = copy(state)
    next.favourites = isPinned(state, id) ? next.favourites.filter(function (one) { return one !== id })
                                           : next.favourites.concat([id])
    return next
}

function hide(state, id) {
    var next = copy(state)
    next.favourites = next.favourites.filter(function (one) { return one !== id })
    if (next.hidden.indexOf(id) < 0)
        next.hidden.push(id)
    return next
}

// Usage goes; what the user chose (favourites, hidden apps) stays.
function clear(state, nonce) {
    var next = copy(state)
    next.history = {}
    next.clearedAt = nonce
    return next
}

// The settings page asks for a clear by writing "<timestamp>" (usage) or
// "<timestamp>:hidden" (hidden apps) to launcher.ini; it runs once, the first
// time a newer timestamp is seen.
function applyRequest(state, request) {
    var parts = String(request).split(":")
    var nonce = Number(parts[0])
    if (!(nonce > state.clearedAt))
        return state
    var next = parts[1] === "hidden" ? copy(state) : clear(state, nonce)
    if (parts[1] === "hidden")
        next.hidden = []
    next.clearedAt = nonce
    return next
}
