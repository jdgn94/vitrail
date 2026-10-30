// Material 3 Expressive shape library and the field outline, as SVG paths.
//
// Every shape comes from one generator: a polygon or a star with `n` points,
// an inner radius ratio (1 = polygon) and a corner roundness `t` in (0, 0.5].
// Each vertex V with neighbours P and N is drawn as
//   L (V + (P - V) t)  Q V  (V + (N - V) t)
// so t = 0.5 turns a many-pointed polygon into a circle.
.pragma library

// n points, inner radius ratio, roundness, start angle (degrees).
var spec = {
    circle: { n: 20, inner: 1, t: 0.5, start: -90 },
    square: { n: 4, inner: 1, t: 0.3, start: -45 },
    triangle: { n: 3, inner: 1, t: 0.3, start: -90 },
    pentagon: { n: 5, inner: 1, t: 0.3, start: -90 },
    gem: { n: 6, inner: 1, t: 0.25, start: -90 },
    cookie4: { n: 4, inner: 0.8, t: 0.5, start: -90 },
    cookie6: { n: 6, inner: 0.86, t: 0.5, start: -90 },
    cookie9: { n: 9, inner: 0.9, t: 0.5, start: -90 },
    cookie12: { n: 12, inner: 0.93, t: 0.5, start: -90 },
    clover4: { n: 4, inner: 0.42, t: 0.5, start: -90 },
    clover8: { n: 8, inner: 0.6, t: 0.5, start: -90 },
    flower: { n: 6, inner: 0.55, t: 0.5, start: -90 },
    sunny: { n: 8, inner: 0.75, t: 0.3, start: -90 },
    burst: { n: 12, inner: 0.7, t: 0.15, start: -90 }
}

var names = Object.keys(spec)

// The shapes that stay distinguishable at text size (the password field).
var distinct = ["circle", "square", "triangle", "clover4", "flower", "burst"]

function round(value) {
    return Math.round(value * 100) / 100
}

function vertices(shape) {
    var count = shape.inner === 1 ? shape.n : shape.n * 2
    var points = []
    for (var i = 0; i < count; i++) {
        var angle = (shape.start + i * 360 / count) * Math.PI / 180
        var radius = shape.inner === 1 || i % 2 === 0 ? 1 : shape.inner
        points.push({ x: radius * Math.cos(angle), y: radius * Math.sin(angle) })
    }
    return points
}

// The rounded corners of every vertex: where each one starts, bends, ends.
function corners(points, t) {
    return points.map(function (v, i) {
        var p = points[(i + points.length - 1) % points.length]
        var n = points[(i + 1) % points.length]
        return {
            from: { x: v.x + (p.x - v.x) * t, y: v.y + (p.y - v.y) * t },
            bend: v,
            to: { x: v.x + (n.x - v.x) * t, y: v.y + (n.y - v.y) * t }
        }
    })
}

function quadAt(c, s) {
    var a = (1 - s) * (1 - s), b = 2 * s * (1 - s), d = s * s
    return {
        x: a * c.from.x + b * c.bend.x + d * c.to.x,
        y: a * c.from.y + b * c.bend.y + d * c.to.y
    }
}

// An SVG path (M … Z) of the named shape, scaled to fill a size × size box.
function path(name, size) {
    var shape = spec[name] || spec.circle
    var list = corners(vertices(shape), shape.t)

    var lo = { x: Infinity, y: Infinity }, hi = { x: -Infinity, y: -Infinity }
    list.forEach(function (c) {
        for (var s = 0; s <= 8; s++) {
            var p = quadAt(c, s / 8)
            lo.x = Math.min(lo.x, p.x); hi.x = Math.max(hi.x, p.x)
            lo.y = Math.min(lo.y, p.y); hi.y = Math.max(hi.y, p.y)
        }
    })
    var scale = size / Math.max(hi.x - lo.x, hi.y - lo.y)
    function place(p) {
        var x = (p.x - (lo.x + hi.x) / 2) * scale + size / 2
        var y = (p.y - (lo.y + hi.y) / 2) * scale + size / 2
        return round(Math.min(size, Math.max(0, x))) + " " + round(Math.min(size, Math.max(0, y)))
    }

    var out = ""
    list.forEach(function (c, i) {
        out += (i === 0 ? "M " : "L ") + place(c.from) + " Q " + place(c.bend) + " " + place(c.to) + " "
    })
    return out + "Z"
}

// A random shape name from `pool` (default: all), never the one in `previous`.
function random(previous, pool) {
    var choices = (pool || names).filter(function (name) { return name !== previous })
    return choices[Math.floor(Math.random() * choices.length)]
}

// The outline of a w × h rounded rect with corner radius r. The top edge is
// open from gapStart for gapWidth (the notch behind a floating label); the
// path runs clockwise from the gap's right end back to its left end. Without
// a gap it is closed.
function outlinePath(w, h, r, gapStart, gapWidth) {
    r = Math.max(0, Math.min(r, w / 2, h / 2))
    var from = Math.max(r, Math.min(gapStart, w - r))
    var to = gapWidth > 0 ? Math.min(w - r, from + gapWidth) : from
    function corner(x, y) {
        return r > 0 ? " A " + r + " " + r + " 0 0 1 " + x + " " + y : ""
    }
    var out = "M " + round(to) + " 0"
    out += " L " + round(w - r) + " 0" + corner(w, r)
    out += " L " + w + " " + round(h - r) + corner(round(w - r), h)
    out += " L " + r + " " + h + corner(0, round(h - r))
    out += " L 0 " + r + corner(r, 0)
    out += " L " + round(from) + " 0"
    return gapWidth > 0 ? out : out + " Z"
}
