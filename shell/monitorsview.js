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

// The resolution a tile names: the chosen mode's, or the live one while the
// mode is "preferred".
function sizeText(monitor, spec) {
    var mode = spec && spec.mode && spec.mode !== "preferred" ? String(spec.mode).split("@")[0] : ""
    if (mode === "")
        mode = (monitor && monitor.width ? monitor.width : 0) + "x" + (monitor && monitor.height ? monitor.height : 0)
    return mode.replace("x", "×")
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

// The layout has no gaps and no overlaps: every output shares an edge segment
// with another, so the outputs form one group. Two rectangles touch when one
// edge is flush against the other and the overlap along it is more than a
// point.
function touching(one, other) {
    if (overlaps(one, other))
        return false
    var rows = Math.min(one.y + one.height, other.y + other.height) - Math.max(one.y, other.y)
    var columns = Math.min(one.x + one.width, other.x + other.width) - Math.max(one.x, other.x)
    var sideways = one.x + one.width === other.x || other.x + other.width === one.x
    var stacked = one.y + one.height === other.y || other.y + other.height === one.y
    return (sideways && rows > 0) || (stacked && columns > 0)
}

// The groups of indices that reach each other through touching edges.
function groups(list) {
    var seen = []
    var out = []
    for (var i = 0; i < list.length; i++) {
        if (seen[i])
            continue
        var group = [i]
        seen[i] = true
        for (var at = 0; at < group.length; at++) {
            for (var j = 0; j < list.length; j++) {
                if (!seen[j] && touching(list[group[at]], list[j])) {
                    seen[j] = true
                    group.push(j)
                }
            }
        }
        out.push(group)
    }
    return out
}

function connected(list) {
    return groups(list || []).length <= 1
}

// How close, in logical points, an edge or a centre must be to another to
// count as lined up: a share of the smaller side, so it follows the output's
// size. It is also the least overlap a joined edge keeps.
var alignShare = 0.04

function threshold(size) {
    return Math.max(1, Math.round(alignShare * Math.min(size.width, size.height)))
}

// The start of a span of `length` that overlaps [low, high) by at least
// `grip`, the nearest to `start`.
function within(start, length, low, high, grip) {
    var most = Math.min(grip, length, high - low)
    return Math.min(Math.max(start, low - length + most), high - most)
}

// The starts a span of `length` can take to line one of its edges or its
// centre up with the same part of any of `spans` ({ start, length }).
function lined(length, spans) {
    var out = []
    for (var i = 0; i < spans.length; i++) {
        out.push(spans[i].start,
                 spans[i].start + (spans[i].length - length) / 2,
                 spans[i].start + spans[i].length - length)
    }
    return out
}

// The offset a dropped rectangle takes along the edge it joins: the nearest
// line-up within `near`, then the user's own offset; both kept overlapping
// that edge. Each is offered, the line-up first.
function slides(want, length, low, high, near, aligned) {
    var pick = null
    for (var i = 0; i < aligned.length; i++) {
        if (Math.abs(aligned[i] - want) <= near
                && (pick === null || Math.abs(aligned[i] - want) < Math.abs(pick - want)))
            pick = aligned[i]
    }
    var grip = Math.min(near, length)
    var out = []
    if (pick !== null)
        out.push(Math.round(within(pick, length, low, high, grip)))
    out.push(Math.round(within(want, length, low, high, grip)))
    return out
}

// A dropped rectangle joins the others: it goes flush against one of their
// edges, overlapping none and sharing a segment of that edge. The nearest such
// place to where it was dropped wins, so the side it was dropped on is kept.
// Along the edge, it lines up with the others' edges or centres when it is
// within the threshold and keeps its own offset otherwise.
function snap(moving, others, x, y) {
    var targetX = Math.round(x)
    var targetY = Math.round(y)
    var list = others || []
    if (list.length === 0)
        return { x: targetX, y: targetY }
    var near = threshold(moving)
    var columns = []
    var rows = []
    for (var i = 0; i < list.length; i++) {
        columns.push({ start: list[i].x, length: list[i].width })
        rows.push({ start: list[i].y, length: list[i].height })
    }
    var alignedX = lined(moving.width, columns)
    var alignedY = lined(moving.height, rows)
    function free(cx, cy) {
        var box = { x: cx, y: cy, width: moving.width, height: moving.height }
        for (var k = 0; k < list.length; k++) {
            if (overlaps(box, list[k]))
                return false
        }
        return true
    }
    var best = null
    var bestDistance = 0
    function offer(cx, cy) {
        if (!free(cx, cy))
            return false
        var gap = distance({ x: cx, y: cy }, targetX, targetY)
        if (best === null || gap < bestDistance) {
            best = { x: cx, y: cy }
            bestDistance = gap
        }
        return true
    }
    for (var n = 0; n < list.length; n++) {
        var other = list[n]
        var sides = [other.x + other.width, other.x - moving.width]
        var offsets = slides(targetY, moving.height, other.y, other.y + other.height, near, alignedY)
        for (var a = 0; a < sides.length; a++) {
            for (var b = 0; b < offsets.length; b++) {
                if (offer(sides[a], offsets[b]))
                    break
            }
        }
        var floors = [other.y + other.height, other.y - moving.height]
        offsets = slides(targetX, moving.width, other.x, other.x + other.width, near, alignedX)
        for (var c = 0; c < floors.length; c++) {
            for (var d = 0; d < offsets.length; d++) {
                if (offer(offsets[d], floors[c]))
                    break
            }
        }
    }
    return best
}

// How far a group of rectangles must slide to join the placed ones: flush
// against one of them, along the axis it shares, overlapping none.
function pull(group, placed) {
    var best = null
    var bestDistance = 0
    function consider(dx, dy) {
        for (var i = 0; i < group.length; i++) {
            var box = { x: group[i].x + dx, y: group[i].y + dy, width: group[i].width, height: group[i].height }
            for (var j = 0; j < placed.length; j++) {
                if (overlaps(box, placed[j]))
                    return
            }
        }
        var gap = dx * dx + dy * dy
        if (best === null || gap < bestDistance) {
            best = { x: dx, y: dy }
            bestDistance = gap
        }
    }
    for (var a = 0; a < group.length; a++) {
        var one = group[a]
        var grip = threshold(one)
        for (var b = 0; b < placed.length; b++) {
            var other = placed[b]
            var along = within(one.y, one.height, other.y, other.y + other.height, grip) - one.y
            var across = within(one.x, one.width, other.x, other.x + other.width, grip) - one.x
            consider(other.x + other.width - one.x, along)
            consider(other.x - one.width - one.x, along)
            consider(across, other.y + other.height - one.y)
            consider(across, other.y - one.height - one.y)
        }
    }
    return best
}

// Closes the gaps of a layout: the group that holds `anchor` stays put and
// every other group slides, the nearest first, until it touches the ones
// already placed. Returns the outputs that move, with their new places.
function tidy(list, anchor) {
    var parts = groups(list || [])
    if (parts.length <= 1)
        return []
    var first = 0
    for (var p = 0; p < parts.length; p++) {
        if (parts[p].some(function (index) { return list[index].name === anchor }))
            first = p
    }
    var placed = parts[first].map(function (index) { return list[index] })
    var rest = parts.filter(function (part, at) { return at !== first })
    var moves = []
    while (rest.length > 0) {
        var pickAt = -1
        var pickBy = null
        var pickDistance = 0
        for (var r = 0; r < rest.length; r++) {
            var group = rest[r].map(function (index) { return list[index] })
            var by = pull(group, placed)
            if (by === null)
                continue
            var gap = by.x * by.x + by.y * by.y
            if (pickBy === null || gap < pickDistance) {
                pickAt = r
                pickBy = by
                pickDistance = gap
            }
        }
        if (pickBy === null)
            break
        rest[pickAt].forEach(function (index) {
            var one = list[index]
            var next = { name: one.name, x: one.x + pickBy.x, y: one.y + pickBy.y,
                         width: one.width, height: one.height }
            placed.push(next)
            if (pickBy.x !== 0 || pickBy.y !== 0)
                moves.push({ name: next.name, x: next.x, y: next.y })
        })
        rest.splice(pickAt, 1)
    }
    return moves
}

// The lines a dragged rectangle lines up with: for each other output, its
// left / centre / right (or top / centre / bottom) within `near` of the same
// part of the other, and the edge it lies flush against. Each is { axis, at,
// kind }, `at` being the coordinate of the other's edge or centre on that
// axis ("x" for a vertical line).
function guides(moving, others, near) {
    var out = []
    var seen = {}
    function add(axis, at, kind) {
        var key = axis + ":" + at + ":" + kind
        if (seen[key])
            return
        seen[key] = true
        out.push({ axis: axis, at: at, kind: kind })
    }
    var list = others || []
    for (var i = 0; i < list.length; i++) {
        var other = list[i]
        var rows = Math.min(moving.y + moving.height, other.y + other.height) - Math.max(moving.y, other.y)
        var columns = Math.min(moving.x + moving.width, other.x + other.width) - Math.max(moving.x, other.x)
        var pairs = [
            ["x", moving.x, other.x, "edge"],
            ["x", moving.x + moving.width / 2, other.x + other.width / 2, "centre"],
            ["x", moving.x + moving.width, other.x + other.width, "edge"],
            ["y", moving.y, other.y, "edge"],
            ["y", moving.y + moving.height / 2, other.y + other.height / 2, "centre"],
            ["y", moving.y + moving.height, other.y + other.height, "edge"]
        ]
        for (var p = 0; p < pairs.length; p++) {
            if (Math.abs(pairs[p][1] - pairs[p][2]) <= near)
                add(pairs[p][0], pairs[p][2], pairs[p][3])
        }
        if (rows > 0) {
            if (Math.abs(moving.x + moving.width - other.x) <= near)
                add("x", other.x, "flush")
            if (Math.abs(moving.x - (other.x + other.width)) <= near)
                add("x", other.x + other.width, "flush")
        }
        if (columns > 0) {
            if (Math.abs(moving.y + moving.height - other.y) <= near)
                add("y", other.y, "flush")
            if (Math.abs(moving.y - (other.y + other.height)) <= near)
                add("y", other.y + other.height, "flush")
        }
    }
    return out
}

// Moves one output to a logical point. While dragging, `snapIt` is false; on
// release it is true and the output joins its neighbours.
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
    var next = moveTo(doc, monitors, name, current.x, current.y, true)
    // Taking an output out of the middle can leave the rest apart: they slide
    // together, and only they, never the one the user placed.
    var moves = tidy(rects(monitors, next), name)
    for (var i = 0; i < moves.length; i++)
        next = set(next, monitors, moves[i].name, { position: moves[i].x + "x" + moves[i].y })
    return next
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
