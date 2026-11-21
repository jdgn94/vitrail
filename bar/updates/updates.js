// The updates element's plain logic: the count the button shows, the
// per-source blocks of the popup, the "new updates" diff rule and the two
// preferences that are lists rather than numbers. No QML type is touched
// here, so tests/qml/tst_updates.qml feeds it plain objects.
.pragma library

// The sources vitrail/updates.py checks, in the order the popup lists them.
var SOURCES = ["official", "aur", "flatpak"]
// How many rows of one source the popup shows before "and N more".
var ROW_LIMIT = 5
// The check interval (`updatesInterval`), in whole minutes.
var INTERVAL_MIN = 5
var INTERVAL_MAX = 720
var INTERVAL_DEFAULT = 60
var MINUTE = 60000

// The enabled sources from the preference's comma list; a key that was never
// written means all three, an explicit empty value means none.
function enabledSources(text) {
    if (text === undefined || text === null)
        return SOURCES.slice()
    var words = String(text).split(",")
    var wanted = []
    for (var i = 0; i < words.length; i++) {
        var word = words[i].trim()
        if (SOURCES.indexOf(word) >= 0 && wanted.indexOf(word) < 0)
            wanted.push(word)
    }
    return SOURCES.filter(function (source) { return wanted.indexOf(source) >= 0 })
}

// The preference's text after `source` is turned on or off.
function withSource(text, source, on) {
    var list = enabledSources(text)
    var at = list.indexOf(source)
    if (on && at < 0 && SOURCES.indexOf(source) >= 0)
        list.push(source)
    else if (!on && at >= 0)
        list.splice(at, 1)
    return SOURCES.filter(function (entry) { return list.indexOf(entry) >= 0 }).join(",")
}

function intervalMinutes(value) {
    var number = Math.round(Number(value))
    if (!isFinite(number))
        return INTERVAL_DEFAULT
    return Math.max(INTERVAL_MIN, Math.min(INTERVAL_MAX, number))
}

// What BarSnapshot polls with.
function intervalMs(value) {
    return intervalMinutes(value) * MINUTE
}

// A snapshot the element can draw: `total` is a number. Anything else (the
// BarSnapshot's `{ error: "unreadable" }`) is an unavailable element.
function ready(snapshot) {
    return !!snapshot && typeof snapshot.total === "number" && isFinite(snapshot.total)
}

function total(snapshot) {
    return ready(snapshot) ? Math.max(0, Math.round(snapshot.total)) : 0
}

// One source's updates, and the ones a failed source explains itself in.
function entries(snapshot, source) {
    var list = (snapshot || ({}))[source]
    return Array.isArray(list) ? list : []
}

// The sources this snapshot enabled, in their canonical order.
function sourcesOf(snapshot) {
    return SOURCES.filter(function (source) {
        return Array.isArray((snapshot || ({}))[source])
    })
}

function errorOf(snapshot, source) {
    var errors = (snapshot || ({})).errors || ({})
    return errors[source] === undefined ? "" : String(errors[source])
}

// The sources with at least one pending update, as { source, count }.
function counts(snapshot) {
    var out = []
    var sources = sourcesOf(snapshot)
    for (var i = 0; i < sources.length; i++) {
        var count = entries(snapshot, sources[i]).length
        if (count > 0)
            out.push({ source: sources[i], count: count })
    }
    return out
}

// "from → to", or just the half the source knows (Flatpak has no installed
// version).
function versions(entry) {
    if (!entry)
        return ""
    var from = entry.from === undefined || entry.from === null ? "" : String(entry.from)
    var to = entry.to === undefined || entry.to === null ? "" : String(entry.to)
    if (from !== "" && to !== "")
        return from + " → " + to
    return to !== "" ? to : from
}

function shown(rows) {
    return (rows || []).slice(0, ROW_LIMIT)
}

function hidden(rows) {
    return Math.max(0, (rows || []).length - ROW_LIMIT)
}

// Every package name of a snapshot, once, in source order.
function names(snapshot) {
    var out = []
    var sources = sourcesOf(snapshot)
    for (var i = 0; i < sources.length; i++) {
        var rows = entries(snapshot, sources[i])
        for (var j = 0; j < rows.length; j++) {
            var name = rows[j] && rows[j].name !== undefined ? String(rows[j].name) : ""
            if (name !== "" && out.indexOf(name) < 0)
                out.push(name)
        }
    }
    return out
}

// What the bar should announce, if anything: the names that appeared since
// `previous`, but only when the total grew too. The first snapshot after start
// is a baseline (previous is null or unusable), so a machine that has been off
// for a week does not fire a toast the moment the bar loads, and a package
// replaced by another (same total) stays quiet.
function notice(previous, next) {
    if (!ready(previous) || !ready(next) || total(next) <= total(previous))
        return { count: 0, names: [] }
    var before = names(previous)
    var fresh = names(next).filter(function (name) { return before.indexOf(name) < 0 })
    return { count: fresh.length, names: fresh }
}
