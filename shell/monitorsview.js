.pragma library

// The Monitors page's pure logic: the override document (JSON text in
// monitors.ini), seeded from Hyprland's live monitor, the draft the organiser
// edits, and the labels the page shows. Keeping it here makes it testable with
// qmltestrunner.
//
// The page never writes a preference while the user drags or edits: it keeps a
// draft document and only hands it to monitors.ini when Apply is pressed.

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

function has(value, key) {
    return Object.prototype.hasOwnProperty.call(value, key)
}

// JSON with sorted keys, so two documents that mean the same compare equal
// whichever order their fields were written in.
function stable(value) {
    if (value === null || typeof value !== "object")
        return JSON.stringify(value)
    if (Array.isArray(value)) {
        return "[" + value.map(function (one) { return stable(one) }).join(",") + "]"
    }
    return "{" + Object.keys(value).sort().map(function (key) {
        return JSON.stringify(key) + ":" + stable(value[key])
    }).join(",") + "}"
}

function sameDoc(a, b) {
    return stable(a || {}) === stable(b || {})
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

// --- the draft ---------------------------------------------------------------

// Every field the document accepts, seeded from the live output. A saved
// override only replaces the fields it actually names.
function normalise(spec, monitor) {
    var base = seed(monitor)
    var out = copy(base)
    if (spec && typeof spec === "object") {
        for (var key in base) {
            if (has(spec, key) && spec[key] !== undefined && spec[key] !== null)
                out[key] = spec[key]
        }
        if (typeof spec.position === "string" && spec.position !== "")
            out.position = spec.position
    }
    if (out.primary !== true)
        delete out.primary
    return out
}

// The output that should be primary when the document says nothing: the one
// Hyprland has focused, then the first enabled output, then the first one.
function defaultPrimary(monitors) {
    var list = monitors || []
    for (var i = 0; i < list.length; i++) {
        if (list[i].focused)
            return list[i].name
    }
    for (var j = 0; j < list.length; j++) {
        if (!list[j].disabled)
            return list[j].name
    }
    return list.length > 0 ? list[0].name : ""
}

function primaryOf(doc) {
    var names = Object.keys(doc || {})
    for (var i = 0; i < names.length; i++) {
        if (doc[names[i]] && doc[names[i]].primary === true)
            return names[i]
    }
    return ""
}

// The full draft: every live output gets a specification, even when it has no
// saved override, so the canvas can place it. `primary` is the name to keep
// when the saved document names none.
function draft(monitors, text, primary) {
    var saved = parse(text)
    var list = monitors || []
    var doc = {}
    var chosen = ""
    for (var i = 0; i < list.length; i++) {
        var name = list[i].name
        var spec = normalise(override(saved, name), list[i])
        if (spec.primary === true && chosen === "")
            chosen = name
        doc[name] = spec
    }
    if (chosen === "" && primary && has(doc, primary))
        chosen = primary
    if (chosen === "" && has(doc, defaultPrimary(list)))
        chosen = defaultPrimary(list)
    for (var key in doc) {
        if (key === chosen)
            doc[key].primary = true
        else
            delete doc[key].primary
    }
    return doc
}

// One monitor's fields, a new document: the page never mutates the draft in
// place, so every binding that reads it re-evaluates.
function set(doc, monitors, name, patch) {
    var monitor = live(monitors, name)
    if (!monitor)
        return doc
    var next = copy(doc || {})
    var spec = normalise(next[name] || seed(monitor), monitor)
    for (var key in patch) {
        if (patch[key] === undefined)
            continue
        if (key === "primary") {
            if (patch[key] === true)
                spec.primary = true
            else
                delete spec.primary
        } else {
            spec[key] = patch[key]
        }
    }
    next[name] = spec
    if (spec.primary === true)
        return setPrimary(next, name)
    return next
}

// Exactly one primary: the named output, and nobody else.
function setPrimary(doc, name) {
    var next = copy(doc || {})
    for (var key in next) {
        if (key === name)
            next[key].primary = true
        else
            delete next[key].primary
    }
    return next
}

// How large an output is in the compositor's logical coordinates: the mode's
// pixels divided by the scale, with a quarter turn swapping the sides.
function extent(monitor, spec) {
    var width = monitor && monitor.width ? Number(monitor.width) : 1920
    var height = monitor && monitor.height ? Number(monitor.height) : 1080
    var degrees = degreesOf(spec && spec.transform !== undefined ? spec.transform : 0)
    if (degrees === 90 || degrees === 270) {
        var swap = width
        width = height
        height = swap
    }
    var scale = spec && Number(spec.scale) > 0 ? Number(spec.scale) : 1
    return { width: Math.max(1, Math.round(width / scale)), height: Math.max(1, Math.round(height / scale)) }
}

// Where an output sits: its explicit position, or the live one when it is
// placed automatically.
function placeOf(monitor, spec) {
    var place = position(spec)
    if (place.auto)
        return { x: monitor && monitor.x ? monitor.x : 0, y: monitor && monitor.y ? monitor.y : 0 }
    return { x: place.x, y: place.y }
}

function rectOf(monitor, spec) {
    var at = placeOf(monitor, spec)
    var size = extent(monitor, spec)
    return {
        name: monitor.name,
        x: at.x,
        y: at.y,
        width: size.width,
        height: size.height,
        disabled: !!(spec && spec.disabled),
        mirror: spec && spec.mirror ? spec.mirror : "",
        primary: !!(spec && spec.primary),
        auto: !!(spec && spec.position && String(spec.position).indexOf("auto") === 0),
        monitor: monitor
    }
}

function rect(monitor, spec) {
    return rectOf(monitor, spec)
}

// The canvas's rectangles, in the order of the live outputs.
function rects(monitors, doc) {
    var list = monitors || []
    var out = []
    for (var i = 0; i < list.length; i++) {
        var spec = override(doc, list[i].name) || seed(list[i])
        out.push(rectOf(list[i], spec))
    }
    return out
}

function rectOfName(monitors, doc, name) {
    var monitor = live(monitors, name)
    if (!monitor)
        return null
    return rectOf(monitor, override(doc, name) || seed(monitor))
}

function bounds(list) {
    if (!list || list.length === 0)
        return { x: 0, y: 0, width: 1, height: 1 }
    var left = list[0].x
    var top = list[0].y
    var right = list[0].x + list[0].width
    var bottom = list[0].y + list[0].height
    for (var i = 1; i < list.length; i++) {
        left = Math.min(left, list[i].x)
        top = Math.min(top, list[i].y)
        right = Math.max(right, list[i].x + list[i].width)
        bottom = Math.max(bottom, list[i].y + list[i].height)
    }
    return { x: left, y: top, width: Math.max(1, right - left), height: Math.max(1, bottom - top) }
}

// How to draw the logical layout inside a canvas of `width` × `height`, with
// a token-sized margin. `x` / `y` are the canvas coordinates of the bounds'
// top-left corner.
function fit(box, width, height, padding) {
    var pad = Number(padding) || 0
    var usableWidth = Math.max(1, Number(width) - 2 * pad)
    var usableHeight = Math.max(1, Number(height) - 2 * pad)
    var scale = Math.min(usableWidth / box.width, usableHeight / box.height)
    scale = Math.max(0.001, scale)
    return {
        scale: scale,
        x: (Number(width) - box.width * scale) / 2 - box.x * scale,
        y: (Number(height) - box.height * scale) / 2 - box.y * scale
    }
}

function overlaps(one, other) {
    return one.x < other.x + other.width && one.x + one.width > other.x
           && one.y < other.y + other.height && one.y + one.height > other.y
}

function distance(one, x, y) {
    var dx = one.x - x
    var dy = one.y - y
    return dx * dx + dy * dy
}

// A dropped rectangle snaps against the edges of the others and never
// overlaps one. The nearest such place to the pointer wins; with no edges to
// touch at all, it stays where it is.
function snap(moving, others, x, y) {
    var targetX = Math.round(x)
    var targetY = Math.round(y)
    var list = others || []
    if (list.length === 0)
        return { x: targetX, y: targetY }
    var candidates = []
    function offer(cx, cy) {
        candidates.push({ x: Math.round(cx), y: Math.round(cy) })
    }
    for (var i = 0; i < list.length; i++) {
        var other = list[i]
        var xs = [other.x, other.x + other.width,
                  other.x - moving.width, other.x + other.width - moving.width]
        var ys = [other.y, other.y + other.height,
                  other.y - moving.height, other.y + other.height - moving.height]
        for (var a = 0; a < xs.length; a++) {
            offer(xs[a], targetY)
            for (var b = 0; b < ys.length; b++)
                offer(xs[a], ys[b])
        }
        for (var c = 0; c < ys.length; c++)
            offer(targetX, ys[c])
    }
    var best = null
    var bestDistance = 0
    for (var j = 0; j < candidates.length; j++) {
        var candidate = candidates[j]
        var free = true
        for (var k = 0; k < list.length; k++) {
            if (overlaps({ x: candidate.x, y: candidate.y,
                           width: moving.width, height: moving.height }, list[k])) {
                free = false
                break
            }
        }
        if (!free)
            continue
        var gap = distance(candidate, targetX, targetY)
        if (best === null || gap < bestDistance) {
            best = candidate
            bestDistance = gap
        }
    }
    if (best !== null)
        return best
    // The others are arranged around the pointer: the nearest free place is
    // beyond their right edge.
    var right = targetX
    for (var n = 0; n < list.length; n++)
        right = Math.max(right, list[n].x + list[n].width)
    return { x: right, y: targetY }
}

// Moves one output to a logical point. While dragging, `snapIt` is false; on
// release it is true and the output snaps to its neighbours.
function moveTo(doc, monitors, name, x, y, snapIt) {
    var monitor = live(monitors, name)
    if (!monitor)
        return doc
    var current = rectOf(monitor, override(doc, name) || seed(monitor))
    var others = []
    var all = rects(monitors, doc)
    for (var i = 0; i < all.length; i++) {
        if (all[i].name !== name)
            others.push(all[i])
    }
    var target = { width: current.width, height: current.height }
    var at = snapIt ? snap(target, others, x, y) : { x: Math.round(x), y: Math.round(y) }
    return set(doc, monitors, name, { position: at.x + "x" + at.y })
}

function drop(doc, monitors, name) {
    var current = rectOfName(monitors, doc, name)
    if (!current)
        return doc
    return moveTo(doc, monitors, name, current.x, current.y, true)
}

// The document text Apply writes. Sorted fields make the applied document
// canonical, so applying the same draft twice writes the same string.
function documentText(doc) {
    return stable(doc || {})
}

// The names whose specification differs between the applied document and the
// draft.
function changed(base, draftDoc) {
    var names = []
    var seen = {}
    var keys = Object.keys(base || {}).concat(Object.keys(draftDoc || {}))
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i]
        if (seen[key])
            continue
        seen[key] = true
        if (!sameDoc(override(base, key), override(draftDoc, key)))
            names.push(key)
    }
    return names
}

function countChanges(base, draftDoc) {
    return changed(base, draftDoc).length
}

function dirty(base, draftDoc) {
    return !sameDoc(base, draftDoc)
}

// The tiny document the page leaves for the bar's monitor overlay.
function indicator(name, active) {
    return stable({ active: active === true && String(name || "") !== "",
                    name: active === true ? String(name || "") : "" })
}

function parseIndicator(text) {
    var data
    try {
        data = JSON.parse(text || "{}")
    } catch (error) {
        data = null
    }
    if (!data || typeof data !== "object")
        return { active: false, name: "" }
    return { active: data.active === true, name: typeof data.name === "string" ? data.name : "" }
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
