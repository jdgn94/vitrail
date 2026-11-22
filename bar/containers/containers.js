// The containers element's plain logic: the running count, the pin order, the
// button each container state allows and the argv the shell runs. No QML type
// is touched here, so tests/qml/tst_containers.qml feeds it plain objects.
.pragma library

// The engines vitrail.containers looks for, in its own order.
var ENGINES = ["docker", "podman"]
var STATES = ["running", "exited", "created", "paused", "restarting", "dead"]
var HEALTHS = ["healthy", "unhealthy", "starting"]

// A snapshot the element can draw: vitrail.containers always prints `engine`
// and `containers`; the BarSnapshot's `{ error: "unreadable" }` is not one.
function ready(snapshot) {
    return !!snapshot && Array.isArray(snapshot.containers)
}

// The engine in use, or "" when neither is installed. No engine is an
// ordinary empty state (the element hides itself), not an error.
function engineOf(snapshot) {
    return ready(snapshot) && typeof snapshot.engine === "string" ? snapshot.engine : ""
}

function count(snapshot) {
    if (!ready(snapshot))
        return 0
    var total = 0
    for (var i = 0; i < snapshot.containers.length; i++) {
        if (isRunning(snapshot.containers[i]))
            total += 1
    }
    return total
}

function containers(snapshot) {
    return ready(snapshot) ? snapshot.containers : []
}

function isRunning(one) {
    return !!one && String(one.state || "") === "running"
}

function byName(snapshot, name) {
    var list = containers(snapshot)
    for (var i = 0; i < list.length; i++) {
        if (String(list[i].name || "") === name)
            return list[i]
    }
    return null
}

// The pin preference: one JSON array of container names, in pin order.
function parsePinned(text) {
    var list = []
    try {
        list = JSON.parse(String(text || "[]"))
    } catch (error) {
        return []
    }
    if (!Array.isArray(list))
        return []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var name = typeof list[i] === "string" ? list[i].trim() : ""
        if (name === "" || out.indexOf(name) >= 0)
            continue
        out.push(name)
    }
    return out
}

// The preference's text after `name` is pinned or unpinned. A container is a
// name: renaming it leaves the old name in the list and shows it as down.
function withPinned(text, name, on) {
    var value = String(name || "").trim()
    var list = parsePinned(text)
    if (value === "")
        return JSON.stringify(list)
    var out = list.filter(function (one) { return one !== value })
    if (on)
        out.push(value)
    return JSON.stringify(out)
}

function isPinned(pinnedText, name) {
    return parsePinned(pinnedText).indexOf(String(name || "")) >= 0
}

// The popup's rows: pinned containers first in their pin order, then the rest
// in the engine's own order. A pin that names nothing any more is skipped
// here (the tooltip still reports it as down).
function ordered(snapshot, pinnedText) {
    var list = containers(snapshot).slice()
    var pins = parsePinned(pinnedText)
    var out = []
    for (var i = 0; i < pins.length; i++) {
        var found = byName(snapshot, pins[i])
        if (found !== null && out.indexOf(found) < 0)
            out.push(found)
    }
    for (var j = 0; j < list.length; j++) {
        if (out.indexOf(list[j]) < 0)
            out.push(list[j])
    }
    return out
}

// Pinned names that are not running: a stopped container, or one that is no
// longer there under that name.
function downPinned(snapshot, pinnedText) {
    var pins = parsePinned(pinnedText)
    var out = []
    for (var i = 0; i < pins.length; i++) {
        var found = byName(snapshot, pins[i])
        if (found === null || !isRunning(found))
            out.push(pins[i])
    }
    return out
}

// Which action a container's state allows. Logs works either way.
function allowed(one, action) {
    if (!one)
        return false
    var running = isRunning(one)
    if (action === "start")
        return !running
    if (action === "stop")
        return running
    if (action === "logs")
        return true
    return false
}

// The argv of one action; an absent engine or an unknown action has none.
function command(engine, action, id) {
    var name = String(engine || "")
    var ident = String(id || "")
    if (ENGINES.indexOf(name) < 0 || ident === "")
        return []
    if (action === "logs")
        return [name, "logs", "--tail", "200", ident]
    if (action === "start" || action === "stop")
        return [name, action, ident]
    return []
}

// The `state` arguments of the engine preference: "auto" follows what is
// installed, an explicit engine asks vitrail.containers for that one.
function engineArguments(option) {
    var name = String(option || "")
    return name === "docker" || name === "podman" ? ["--engine", name] : []
}

function stateKey(one) {
    var state = one ? String(one.state || "") : ""
    return STATES.indexOf(state) >= 0 ? "bar.containers.state." + state : ""
}

function healthKey(one) {
    var health = one && one.health ? String(one.health) : ""
    return HEALTHS.indexOf(health) >= 0 ? "bar.containers.health." + health : ""
}
