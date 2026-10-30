// Screen frame geometry: the content hole, the bar slot and the exclusive
// zones, for any frame variant × bar variant × edge. Pure, so it is tested.
.pragma library

var edges = ["left", "top", "right", "bottom"]

// frame, bar: resolved variants; bar is null on a screen without a bar.
// sizes: { frame, bar, gap, radius } in px.
// panel: { variant, extent, push } or null. A full (attached) panel grows the
// frame on the bar edge and reserves space only when it pushes the windows.
function layout(frame, bar, edge, sizes, panel) {
    var side = edges.indexOf(edge) < 0 ? "left" : edge
    var border = frame.border ? sizes.frame : 0
    var radius = frame.corners ? sizes.radius : 0
    var hole = { left: border, top: border, right: border, bottom: border }
    var reserve = { left: border, top: border, right: border, bottom: border }

    if (bar && bar.docked) {
        hole[side] = sizes.bar
        reserve[side] = sizes.bar
    } else if (bar) {
        reserve[side] = border + sizes.gap + sizes.bar
    }

    // Panels open past the bar, floating or docked.
    var start = reserve[side]
    var attached = panel ? panel.variant.attached : false
    var extent = panel ? panel.extent : 0
    if (attached && extent > 0) {
        hole[side] = start + extent
        if (panel.push)
            reserve[side] += extent
    }

    var docked = !bar || bar.docked
    var floatInset = docked ? 0 : border + sizes.gap
    return {
        edge: side,
        hole: hole,
        radius: radius,
        reserve: reserve,
        bar: {
            offset: floatInset,
            margin: floatInset,
            // Docked content clears the inner corners where the frame curves.
            padding: docked ? border + radius : 0
        },
        panel: {
            edge: side,
            // Where the panel begins, measured from the screen edge.
            start: attached ? start : start + sizes.gap,
            extent: extent
        }
    }
}

// Screen point for a point in the frame turned so that `edge` is on the left,
// and back. Rotations only, so arc sweeps keep their meaning.
function turn(edge, width, height, x, y) {
    switch (edge) {
    case "top": return [width - y, x]
    case "right": return [width - x, height - y]
    case "bottom": return [y, height - x]
    default: return [x, y]
    }
}

function unturn(edge, width, height, x, y) {
    switch (edge) {
    case "top": return [y, width - x]
    case "right": return [width - x, height - y]
    case "bottom": return [height - y, x]
    default: return [x, y]
    }
}

// SVG outline of the content hole. Each tab { edge, rect, reveal } is the
// screen rect of a card docked on that edge (a bar popup, the notification
// stack): the hole bends around it, so the frame grows a rounded tongue
// joined to the edge by concave fillets. A tab flush with an end of its edge
// takes that corner and joins the perpendicular edge too. reveal (0..1)
// scales its depth.
function holePath(width, height, hole, radius, tabs) {
    var R = radius
    var frames = {}
    var bumps = {}
    var out = []

    function n(v) { return String(Math.round(v * 100) / 100) }

    // Every edge is walked in its own turned frame, where it is the left
    // side and the walk runs up it: left, top, right, bottom is clockwise.
    edges.forEach(function (side, at) {
        var turned = side === "top" || side === "bottom"
        frames[side] = {
            w: turned ? height : width, h: turned ? width : height,
            l: hole[side], t: hole[edges[(at + 1) % 4]],
            r: hole[edges[(at + 2) % 4]], b: hole[edges[(at + 3) % 4]]
        }
        bumps[side] = []
    })

    ;(tabs || []).forEach(function (tab) {
        var side = edges.indexOf(tab.edge) < 0 ? "left" : tab.edge
        var k = frames[side]
        var a = unturn(side, width, height, tab.rect.x, tab.rect.y)
        var z = unturn(side, width, height, tab.rect.x + tab.rect.width, tab.rect.y + tab.rect.height)
        var d = (Math.max(a[0], z[0]) - k.l) * (tab.reveal === undefined ? 1 : tab.reveal)
        var s = Math.min(a[1], z[1]), e = Math.max(a[1], z[1])
        if (d > 0 && e > s)
            bumps[side].push({ d: d, s: s, e: e, f: Math.min(R, d), c: Math.min(R, d / 2, (e - s) / 2),
                               top: s <= k.t + 0.5, bottom: e >= k.h - k.b - 0.5 })
    })

    edges.forEach(function (side, at) {
        var k = frames[side]
        var l = k.l, t = k.t, h = k.h, b = k.b
        var list = bumps[side].sort(function (x, y) { return y.s - x.s })
        function pt(x, y) { var p = turn(side, width, height, x, y); return n(p[0]) + " " + n(p[1]) }
        function line(x, y) { return "L" + pt(x, y) }
        function arc(rad, sweep, x, y) { return "A" + n(rad) + " " + n(rad) + " 0 0 " + sweep + " " + pt(x, y) }

        list.forEach(function (u) {
            if (u.bottom)
                out.push(line(l + u.d + u.f, h - b), arc(u.f, 1, l + u.d, h - b - u.f))
            else
                out.push(line(l, u.e + u.f), arc(u.f, 1, l + u.f, u.e),
                         line(l + u.d - u.c, u.e), arc(u.c, 0, l + u.d, u.e - u.c))
            if (u.top)
                out.push(line(l + u.d, t + u.f), arc(u.f, 1, l + u.d + u.f, t))
            else
                out.push(line(l + u.d, u.s + u.c), arc(u.c, 0, l + u.d - u.c, u.s),
                         line(l + u.f, u.s), arc(u.f, 1, l, u.s - u.f))
        })

        // The corner into the next edge, unless a tab on either side took it.
        var taken = list.some(function (u) { return u.top })
                    || bumps[edges[(at + 1) % 4]].some(function (u) { return u.bottom })
        if (!taken)
            out.push(line(l, t + R), arc(R, 1, l + R, t))
    })

    out[0] = "M" + out[0].slice(1)
    out.push("Z")
    return out.join(" ")
}

// Where a bar popup starts along the bar, between the hole ends lo and hi:
// centred on its anchor. Docked, one that would come within a corner and a
// fillet of an end snaps flush to it; floating, it keeps a gap from both.
function popupAlong(anchor, size, lo, hi, docked, gap, radius) {
    var min = docked ? lo : lo + gap
    var max = docked ? hi - size : hi - size - gap
    var at = Math.max(min, Math.min(anchor - size / 2, max))
    if (docked && at < min + 2 * radius)
        return min
    if (docked && at > max - 2 * radius)
        return max
    return at
}

// Where the notification stack sits for a position such as "top-right".
// Docked, flush with the hole, as a tab of the frame on its top or bottom
// edge; floating, a gap inside the space the bar and the frame leave.
function stackRect(position, width, height, w, h, layout, docked, gap) {
    var parts = position.split("-")
    var vertical = parts[0] === "bottom" ? "bottom" : "top"
    var across = parts[1] === "left" || parts[1] === "center" ? parts[1] : "right"
    var bounds = docked ? layout.hole : layout.reserve
    var g = docked ? 0 : gap
    var x = across === "left" ? bounds.left + g
          : across === "right" ? width - bounds.right - g - w
          : bounds.left + (width - bounds.left - bounds.right - w) / 2
    var y = vertical === "top" ? bounds.top + g : height - bounds.bottom - g - h
    return { x: x, y: y, edge: vertical }
}
