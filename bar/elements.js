// The bar elements' shared logic: which ones show only while active
// (bar.ini `barActiveOnly`, one JSON array of element ids), and how a Python
// snapshot reaches QML. Pure functions, used by the shell and the settings
// window.
.pragma library

// The elements that show only while they have something to say when the
// preference has never been written. The updates element is the case the plan
// describes ("appears while there is something to say"): its count is its
// whole message, so it starts in "only while active". The disks element joins
// it: with nothing plugged in there is no drive to name. The peripherals
// battery joins them: no watched device reporting a percentage means no number
// for the bar. Updates, disks, containers, the peripheral batteries, health
// and privacy start here; an explicit preference (even "[]") always wins. The
// market element joins them: with no price in the snapshot (a cold cache and
// no network) it has no number for the bar.
var DEFAULT_ACTIVE_ONLY = ["updates", "disks", "containers", "peripherals", "health", "privacy", "market"]

// The ids that show only while active, from the preference's text.
function parseActiveOnly(text) {
    var list = []
    try {
        list = JSON.parse(String(text || "[]"))
    } catch (error) {
        return []
    }
    if (!Array.isArray(list))
        return []
    return list.filter(function (id, index) {
        return typeof id === "string" && id !== "" && list.indexOf(id) === index
    })
}

// The preference's text, with the built-in default when the key is unset.
function activeOnly(text) {
    return parseActiveOnly(text === undefined || text === null ? JSON.stringify(DEFAULT_ACTIVE_ONLY) : text)
}

// "active" or "always" (the default) for one element.
function showMode(list, id) {
    return list.indexOf(id) >= 0 ? "active" : "always"
}

// The preference's text after `id` takes `mode`.
function withShowMode(list, id, mode) {
    var rest = list.filter(function (entry) { return entry !== id })
    if (mode === "active")
        rest.push(id)
    return JSON.stringify(rest)
}

// A Python snapshot's stdout as an object. Anything that is not a JSON object
// is data too: `{ error: "unreadable" }`, so an element can say it has nothing
// instead of keeping a stale answer.
function snapshot(text) {
    var value = null
    try {
        value = JSON.parse(String(text || ""))
    } catch (error) {
        return { error: "unreadable" }
    }
    if (value === null || typeof value !== "object" || Array.isArray(value))
        return { error: "unreadable" }
    return value
}
