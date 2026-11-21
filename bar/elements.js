// The bar elements' shared logic: which ones show only while active
// (bar.ini `barActiveOnly`, one JSON array of element ids), and how a Python
// snapshot reaches QML. Pure functions, used by the shell and the settings
// window.
.pragma library

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
