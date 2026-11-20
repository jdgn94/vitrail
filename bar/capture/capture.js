// Geometry of the capture overlay: the selection rectangle, its handles, the
// toolbar's seat and the points each monitor's surface sees. Pure, so it is
// tested (tests/qml/tst_capture_geometry.qml).
//
// A rectangle is { x, y, w, h } in layout coordinates (the ones
// `hyprctl monitors -j` reports) unless a function says otherwise; a monitor
// is { x, y, width, height, scale }; a bounds is a rectangle.
.pragma library

var HANDLES = ["nw", "n", "ne", "e", "se", "s", "sw", "w"]

// The toolbar keeps this far from the selection and from the monitor's edge.
var GAP = 8
// Smallest area a drag or a handle may leave.
var MIN = 1

function rectOf(edges) {
    return { x: edges.left, y: edges.top, w: edges.right - edges.left, h: edges.bottom - edges.top }
}

// The rectangle between two points, whichever way the drag went.
function normalize(from, to) {
    return {
        x: Math.min(from.x, to.x),
        y: Math.min(from.y, to.y),
        w: Math.abs(to.x - from.x),
        h: Math.abs(to.y - from.y),
    }
}

function inside(point, rect) {
    return rect !== null && point.x >= rect.x && point.x < rect.x + rect.w
        && point.y >= rect.y && point.y < rect.y + rect.h
}

function move(rect, dx, dy, bounds) {
    if (!rect)
        return null
    var x = rect.x + dx
    var y = rect.y + dy
    x = bounds.w <= rect.w ? bounds.x : Math.min(Math.max(x, bounds.x), bounds.x + bounds.w - rect.w)
    y = bounds.h <= rect.h ? bounds.y : Math.min(Math.max(y, bounds.y), bounds.y + bounds.h - rect.h)
    return { x: x, y: y, w: rect.w, h: rect.h }
}

// One edge (or two, at a corner) follows the pointer; the others stay.
function resize(rect, handle, dx, dy, bounds, min) {
    if (!rect || HANDLES.indexOf(handle) < 0)
        return rect
    min = min > 0 ? min : MIN
    var edges = { left: rect.x, top: rect.y, right: rect.x + rect.w, bottom: rect.y + rect.h }
    var west = handle.indexOf("w") >= 0
    var east = handle.indexOf("e") >= 0
    var north = handle.indexOf("n") >= 0
    var south = handle.indexOf("s") >= 0

    if (west)
        edges.left = Math.min(edges.left + dx, edges.right - min)
    if (east)
        edges.right = Math.max(edges.right + dx, edges.left + min)
    if (north)
        edges.top = Math.min(edges.top + dy, edges.bottom - min)
    if (south)
        edges.bottom = Math.max(edges.bottom + dy, edges.top + min)

    edges.left = Math.max(edges.left, bounds.x)
    edges.top = Math.max(edges.top, bounds.y)
    edges.right = Math.min(edges.right, bounds.x + bounds.w)
    edges.bottom = Math.min(edges.bottom, bounds.y + bounds.h)

    if (edges.right - edges.left < min) {
        if (west)
            edges.left = edges.right - min
        else
            edges.right = edges.left + min
    }
    if (edges.bottom - edges.top < min) {
        if (north)
            edges.top = edges.bottom - min
        else
            edges.bottom = edges.top + min
    }
    return rectOf(edges)
}

// "nw"|"n"|"ne"|"e"|"se"|"s"|"sw"|"w" on the border, "inside" in the middle of
// an area, "" anywhere else.
function handleAt(point, rect, tolerance) {
    if (!rect)
        return ""
    var slack = tolerance > 0 ? tolerance : 6
    var left = rect.x
    var top = rect.y
    var right = rect.x + rect.w
    var bottom = rect.y + rect.h
    // A handle is on the border *and* inside the rect's other span, so a
    // pointer far to the left of the area never grabs its top edge.
    var beside = point.y >= top - slack && point.y <= bottom + slack
    var above = point.x >= left - slack && point.x <= right + slack
    var vertical = !beside ? ""
        : point.x >= left - slack && point.x <= left + slack ? "w"
        : point.x >= right - slack && point.x <= right + slack ? "e" : ""
    var horizontal = !above ? ""
        : point.y >= top - slack && point.y <= top + slack ? "n"
        : point.y >= bottom - slack && point.y <= bottom + slack ? "s" : ""
    if (vertical !== "" && horizontal !== "")
        return horizontal + vertical
    if (vertical !== "")
        return vertical
    if (horizontal !== "")
        return horizontal
    return inside(point, rect) ? "inside" : ""
}

// The monitor's own coordinates for a layout point (and back).
function toLocal(point, monitor) {
    return { x: point.x - monitor.x, y: point.y - monitor.y }
}

function toLayout(point, monitor) {
    return { x: point.x + monitor.x, y: point.y + monitor.y }
}

function toLocalRect(rect, monitor) {
    if (!rect)
        return null
    return { x: rect.x - monitor.x, y: rect.y - monitor.y, w: rect.w, h: rect.h }
}

// Where the toolbar goes: under the area when it fits, above when it does not,
// inside its bottom edge as a last resort. All in the same space as `rect`.
function toolbarPlacement(rect, screen, size) {
    var x = rect.x + rect.w / 2 - size.w / 2
    x = Math.min(Math.max(x, screen.x + GAP), Math.max(screen.x + GAP, screen.x + screen.w - size.w - GAP))
    var below = rect.y + rect.h + GAP
    if (below + size.h <= screen.y + screen.h - GAP)
        return { x: x, y: below }
    var above = rect.y - GAP - size.h
    if (above >= screen.y + GAP)
        return { x: x, y: above }
    var insideArea = rect.y + rect.h - size.h - GAP
    var lowest = screen.y + screen.h - size.h - GAP
    return { x: x, y: Math.min(Math.max(insideArea, screen.y + GAP), Math.max(screen.y + GAP, lowest)) }
}

// The longest question "Ask AI" sends.
var QUESTION_MAX = 500

// What was typed in the question field: one line, trimmed, capped.
function question(text) {
    return String(text || "").replace(/\s+/g, " ").trim().slice(0, QUESTION_MAX)
}

// A web link is the only thing a code or a card offers to open.
function isUrl(text) {
    return /^https?:\/\/\S+$/.test(String(text || ""))
}

// A background answer (text detection) counts only for the selection it was
// asked about: `token` grows with every settled selection.
function fresh(token, current) {
    return token === current
}

function clamp(value, low, high) {
    return Math.min(Math.max(value, low), high)
}

// The monitor an area starts on (a pin lives there), null outside the layout.
function monitorOf(rect, monitors) {
    for (var index = 0; index < monitors.length; index++) {
        var one = monitors[index]
        if (rect.x >= one.x && rect.x < one.x + one.width && rect.y >= one.y && rect.y < one.y + one.height)
            return one
    }
    return null
}

// Where a pin opens: on top of the area it was taken from (monitor
// coordinates), scaled down when the area is bigger than its monitor and
// pushed back inside it.
function pinStart(rect, monitor) {
    var zoom = Math.min(1, monitor.width / rect.w, monitor.height / rect.h)
    return {
        x: clamp(rect.x - monitor.x, 0, Math.max(0, monitor.width - rect.w * zoom)),
        y: clamp(rect.y - monitor.y, 0, Math.max(0, monitor.height - rect.h * zoom)),
        zoom: zoom
    }
}

// The wheel scales the pin around the pointer, so what is under it stays put.
function pinZoom(pin, factor, anchor, low, high) {
    var zoom = clamp(pin.zoom * factor, low, high)
    var ratio = zoom / pin.zoom
    return { x: anchor.x - (anchor.x - pin.x) * ratio, y: anchor.y - (anchor.y - pin.y) * ratio, zoom: zoom }
}

function pinOpacity(value, delta, low) {
    return clamp(value + delta, low, 1)
}

// A colour's share of the area as the card shows it: whole percent, "<1%"
// for what rounds to nothing.
function shareLabel(share) {
    var percent = Math.round(share * 100)
    return percent < 1 ? "<1%" : percent + "%"
}

function label(rect) {
    if (!rect)
        return ""
    return Math.round(rect.w) + " × " + Math.round(rect.h)
}

// The rectangle that contains every monitor.
function boundsOf(monitors) {
    if (!monitors || monitors.length === 0)
        return { x: 0, y: 0, w: 0, h: 0 }
    var left = Infinity
    var top = Infinity
    var right = -Infinity
    var bottom = -Infinity
    for (var index = 0; index < monitors.length; index++) {
        var one = monitors[index]
        left = Math.min(left, one.x)
        top = Math.min(top, one.y)
        right = Math.max(right, one.x + one.width)
        bottom = Math.max(bottom, one.y + one.height)
    }
    return { x: left, y: top, w: right - left, h: bottom - top }
}

// The drawn area is a visual rect that trails the exact selection (liquid
// motion); these are its pure geometry.

// A rect as the { x, y, width, height } box frame.js `goo` draws.
function boxOf(rect) {
    return { x: rect.x, y: rect.y, width: rect.w, height: rect.h }
}

// A drop `size` wide centred on a point.
function dropAt(point, size) {
    return { x: point.x - size / 2, y: point.y - size / 2, w: size, h: size }
}

function centreOf(rect) {
    return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 }
}

// How far (px) the drawn rect still is from the exact one: its widest edge.
function strain(exact, shown) {
    if (!exact || !shown)
        return 0
    return Math.max(Math.abs(exact.x - shown.x), Math.abs(exact.y - shown.y),
                    Math.abs(exact.x + exact.w - shown.x - shown.w),
                    Math.abs(exact.y + exact.h - shown.y - shown.h))
}

// Surface tension: the corner radius swells with what the drawn rect still has
// to travel and settles to `rest` once it has caught up. `tension` is
// { rest, swell, max }; the radius never exceeds half the drawn rect's sides,
// so a drop is a circle.
function softRadius(exact, shown, tension) {
    if (!shown)
        return tension.rest
    var radius = Math.min(tension.rest + strain(exact, shown) * tension.swell, tension.max)
    return Math.max(0, Math.min(radius, shown.w / 2, shown.h / 2))
}

// How far the middle of each edge bulges: `exact` is where the area is going,
// `shown` where it is. An edge that still has to move outward (a growing side)
// bulges outward ahead of itself; one that still has to move inward (a trailing
// side) dents, so a moving area stretches along its motion. The bow is capped
// by tension.bowMax and a fifth of the shorter side, so edges never cross.
// Returns { n, e, s, w }, px, positive outward.
function edgeBows(exact, shown, tension) {
    var none = { n: 0, e: 0, s: 0, w: 0 }
    if (!exact || !shown || !(tension.bow > 0))
        return none
    var cap = Math.min(tension.bowMax, 0.2 * Math.min(shown.w, shown.h))
    function bow(travel) {
        return Math.max(-cap, Math.min(cap, travel * tension.bow))
    }
    return {
        n: bow(shown.y - exact.y),
        e: bow(exact.x + exact.w - shown.x - shown.w),
        s: bow(exact.y + exact.h - shown.y - shown.h),
        w: bow(shown.x - exact.x)
    }
}

// The area's outline: a rounded rectangle whose four sides bow by `bows`
// (cubics, so the middle of a side is displaced by exactly its bow).
function outline(rect, bows, radius) {
    if (!(rect.w > 0) || !(rect.h > 0))
        return ""
    var k = 0.552284749831
    var x = rect.x, y = rect.y, w = rect.w, h = rect.h
    var r = Math.max(0, Math.min(radius, w / 2, h / 2))
    var top = w - 2 * r, side = h - 2 * r
    var n = 4 / 3 * bows.n, e = 4 / 3 * bows.e, s = 4 / 3 * bows.s, west = 4 / 3 * bows.w
    function p(px, py) {
        return (Math.round(px * 100) / 100) + " " + (Math.round(py * 100) / 100)
    }
    return "M" + p(x + r, y)
        + " C" + p(x + r + top / 3, y - n) + " " + p(x + w - r - top / 3, y - n) + " " + p(x + w - r, y)
        + " C" + p(x + w - r + k * r, y) + " " + p(x + w, y + r - k * r) + " " + p(x + w, y + r)
        + " C" + p(x + w + e, y + r + side / 3) + " " + p(x + w + e, y + h - r - side / 3) + " " + p(x + w, y + h - r)
        + " C" + p(x + w, y + h - r + k * r) + " " + p(x + w - r + k * r, y + h) + " " + p(x + w - r, y + h)
        + " C" + p(x + w - r - top / 3, y + h + s) + " " + p(x + r + top / 3, y + h + s) + " " + p(x + r, y + h)
        + " C" + p(x + r - k * r, y + h) + " " + p(x, y + h - r + k * r) + " " + p(x, y + h - r)
        + " C" + p(x - west, y + h - r - side / 3) + " " + p(x - west, y + r + side / 3) + " " + p(x, y + r)
        + " C" + p(x, y + r - k * r) + " " + p(x + r - k * r, y) + " " + p(x + r, y) + " Z"
}

// Where the eight grips sit on that outline: the middle of each bowed side and
// the point of each rounded corner.
function grips(rect, bows, radius) {
    var r = Math.max(0, Math.min(radius, rect.w / 2, rect.h / 2))
    var c = r * (1 - Math.SQRT1_2)
    var right = rect.x + rect.w
    var bottom = rect.y + rect.h
    return [
        ["nw", rect.x + c, rect.y + c],
        ["n", rect.x + rect.w / 2, rect.y - bows.n],
        ["ne", right - c, rect.y + c],
        ["e", right + bows.e, rect.y + rect.h / 2],
        ["se", right - c, bottom - c],
        ["s", rect.x + rect.w / 2, bottom + bows.s],
        ["sw", rect.x + c, bottom - c],
        ["w", rect.x - bows.w, rect.y + rect.h / 2]
    ]
}

// Longest time (s) one spring step covers: a stalled frame must not throw an
// edge across the screen.
var SPRING_DT_MAX = 1 / 30

// One frame of a damped spring (one edge of the drawn area) toward `target`:
// `state` is { x, v } (px, px/s), `params` { spring (stiffness, 1/s^2 per unit
// mass), damping (ratio, 1 = critical, none above), mass, epsilon (px at rest) }.
// The closed-form solution, so the result does not depend on how the time is
// cut, a critically damped edge cannot overshoot and a new target keeps the
// velocity. Returns { x, v, rest }; at rest x is exactly the target.
function springStep(state, target, dt, params) {
    var t = Math.max(0, Math.min(dt, SPRING_DT_MAX))
    var w = Math.sqrt(params.spring / params.mass)
    var z = Math.max(0, Math.min(params.damping, 1))
    var d = state.x - target
    var v = state.v
    var e = Math.exp(-z * w * t)
    var nd, nv
    if (z > 1 - 1e-6) {
        var b = v + w * d
        nd = e * (d + b * t)
        nv = e * (v - w * b * t)
    } else {
        var wd = w * Math.sqrt(1 - z * z)
        var c = Math.cos(wd * t)
        var s = Math.sin(wd * t)
        nd = e * (d * c + (v + z * w * d) / wd * s)
        nv = e * (v * c - (w * w * d + z * w * v) / wd * s)
    }
    if (Math.abs(nd) < params.epsilon && Math.abs(nv) < params.epsilon * w)
        return { x: target, v: 0, rest: true }
    return { x: target + nd, v: nv, rest: false }
}
