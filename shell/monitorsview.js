.pragma library

// The Monitors page's pure logic: the override document (JSON text in
// monitors.ini), seeded from Hyprland's live monitor, plus the labels the page
// shows. Keeping it here makes it testable with qmltestrunner.

// A document from its text. Anything that is not an object is empty.
function parse(text) {
    var doc
    try {
        doc = JSON.parse(text)
    } catch (error) {
        doc = null
    }
    return doc && typeof doc === "object" && !Array.isArray(doc) ? doc : {}
}

function stringify(doc) {
    return JSON.stringify(doc)
}

function copy(value) {
    return JSON.parse(JSON.stringify(value))
}

function override(doc, name) {
    return doc[name] && typeof doc[name] === "object" ? doc[name] : null
}

// What the page starts from when a monitor has no override yet: the live
// state, so changing one field keeps the rest as they are on screen.
function seed(monitor) {
    return {
        mode: monitor && monitor.mode ? monitor.mode : "preferred",
        position: monitor ? (monitor.x || 0) + "x" + (monitor.y || 0) : "auto",
        scale: monitor && monitor.scale ? monitor.scale : 1,
        transform: monitor && monitor.transform ? monitor.transform : 0,
        disabled: monitor ? !!monitor.disabled : false,
        mirror: monitor && monitor.mirror ? monitor.mirror : ""
    }
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b)
}

// The new document text for one patch, or null when nothing changed.
function update(text, name, patch, monitor) {
    var doc = parse(text)
    var base = override(doc, name)
    var next = copy(base || seed(monitor))
    for (var key in patch)
        next[key] = patch[key]
    if (base && same(base, next))
        return null
    doc[name] = next
    return stringify(doc)
}

// The new document text without that monitor, or null when it had none.
function remove(text, name) {
    var doc = parse(text)
    if (!doc[name])
        return null
    delete doc[name]
    return stringify(doc)
}

// "2560x1440@180.00" reads as "2560 × 1440 · 180 Hz".
function modeLabel(mode) {
    if (!mode || mode === "preferred")
        return ""
    var parts = mode.split("@")
    var size = parts[0].split("x")
    var label = size[0] + " × " + size[1]
    if (parts[1])
        label += " · " + Math.round(parseFloat(parts[1])) + " Hz"
    return label
}

// What the monitor is showing now.
function label(monitor) {
    if (!monitor)
        return ""
    return monitor.width + " × " + monitor.height + " · " + Math.round(monitor.refresh) + " Hz"
}

// The current mode first, then the listed ones, without repeating it.
function modes(monitor) {
    var list = ["preferred"]
    var found = monitor && monitor.modes ? monitor.modes : []
    for (var i = 0; i < found.length; i++) {
        if (list.indexOf(found[i]) < 0)
            list.push(found[i])
    }
    return list
}

// The field stores Hyprland's transform; the page offers degrees.
function transformOf(degrees) {
    return Math.round(Number(degrees) / 90) % 4
}

function degreesOf(transform) {
    return (Number(transform) % 4) * 90
}

// A position from a parsed override: { auto, x, y }.
function position(spec) {
    var value = spec && spec.position ? spec.position : "auto"
    if (value.indexOf("auto") === 0)
        return { auto: true, x: 0, y: 0 }
    var parts = value.split("x")
    return { auto: false, x: Number(parts[0]) || 0, y: Number(parts[1]) || 0 }
}

function positionText(place) {
    return place.auto ? "auto" : place.x + "x" + place.y
}

// The other outputs, for the mirror list.
function others(monitors, name) {
    var list = []
    for (var i = 0; i < monitors.length; i++) {
        if (monitors[i].name !== name)
            list.push(monitors[i].name)
    }
    return list
}

// The live entry of one output, or null.
function live(monitors, name) {
    for (var i = 0; i < monitors.length; i++) {
        if (monitors[i].name === name)
            return monitors[i]
    }
    return null
}
