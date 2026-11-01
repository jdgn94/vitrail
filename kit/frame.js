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

    if (bar && bar.docked && bar.islands) {
        // Islands rise out of a thin frame; windows still keep clear of them.
        reserve[side] = sizes.bar
    } else if (bar && bar.docked) {
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
    // Where cards docked into the frame (popups, the notification stack) hang
    // from: the hole, or past the islands of an islands bar.
    var dock = {}
    edges.forEach(function (name) {
        dock[name] = docked ? Math.max(hole[name], reserve[name]) : hole[name]
    })
    var floatInset = docked ? 0 : border + sizes.gap
    return {
        edge: side,
        hole: hole,
        dock: dock,
        radius: radius,
        reserve: reserve,
        bar: {
            offset: floatInset,
            margin: floatInset,
            // Docked content clears the inner corners where the frame curves;
            // an island sits in the corner, so only the frame border.
            padding: !docked ? 0 : bar && bar.islands ? border : border + radius
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

// The islands of an islands bar: one rect per slot group, in screen
// coordinates. groups = [{ at: "start" | "center" | "end", rect }] are the
// content rects of the non-empty groups; sizes = { bar, pad, inset }: the bar
// thickness, the padding around a group and the distance of the island from
// the screen edge (0 docked, frame + gap floating). merge (docked) stretches
// the first and last group to the screen ends, into the corner.
function islands(groups, edge, width, height, sizes, merge) {
    var side = edges.indexOf(edge) < 0 ? "left" : edge
    var vertical = side === "left" || side === "right"
    var length = vertical ? height : width
    return groups.map(function (group) {
        var r = group.rect
        var from = (vertical ? r.y : r.x) - sizes.pad
        var to = (vertical ? r.y + r.height : r.x + r.width) + sizes.pad
        if (merge && group.at === "start")
            from = 0
        if (merge && group.at === "end")
            to = length
        var across = side === "right" ? width - sizes.inset - sizes.bar
                   : side === "bottom" ? height - sizes.inset - sizes.bar : sizes.inset
        return vertical ? { x: across, y: from, width: sizes.bar, height: to - from }
                        : { x: from, y: across, width: to - from, height: sizes.bar }
    })
}

// How deep the tabs on one edge reach along it, between lo and hi (the hole's
// ends): the max depth over every interval, adjacent equal depths merged.
// Segments run from the far end (hi) back to the near one (lo), the way the
// edge is walked: [{ s, e, d, k }] with s < e; k is the fillet swell of the
// deepest tab there (1 = normal).
function profile(bumps, lo, hi) {
    var cuts = [lo, hi]
    bumps.forEach(function (u) { cuts.push(Math.max(lo, u.s), Math.min(hi, u.e)) })
    cuts.sort(function (x, y) { return x - y })
    var kept = [cuts[0]]
    cuts.forEach(function (c) {
        if (c - kept[kept.length - 1] > 0.5)
            kept.push(c)
    })
    kept[kept.length - 1] = hi

    var out = []
    for (var i = kept.length - 1; i > 0; i--) {
        var mid = (kept[i - 1] + kept[i]) / 2
        var d = 0, k = 1
        bumps.forEach(function (u) {
            if (u.s < mid && mid < u.e && (u.d > d || (u.d === d && u.k > k))) {
                d = u.d
                k = u.k
            }
        })
        var last = out[out.length - 1]
        if (last && Math.abs(last.d - d) < 0.01) {
            last.s = kept[i - 1]
            last.k = Math.max(last.k, k)
        } else {
            out.push({ s: kept[i - 1], e: kept[i], d: d, k: k })
        }
    }
    return out.length > 0 ? out : [{ s: lo, e: hi, d: 0, k: 1 }]
}

// SVG outline of the content hole. Each tab { edge, rect, reveal } is the
// screen rect of a card docked on that edge (a bar popup, the notification
// stack, an island of the bar): the hole bends around it, so the frame grows
// a rounded tongue joined to the edge by concave fillets. reveal (0..1, may
// overshoot a little) scales its depth past `base` (px, default 0: the depth
// it starts from, e.g. the island it grows out of); swell (default 1)
// multiplies the radius of its fillets. Tabs on one edge may overlap (a popup rising out of an
// island): they merge into a depth profile and every step of it is rounded,
// the corner at the shallower depth bending like a base fillet, the one at
// the deeper depth like a tab corner. A profile flush with an end of its edge
// takes that corner and joins the perpendicular edge too.
function holePath(width, height, hole, radius, tabs) {
    var R = radius
    var frames = {}
    var bumps = {}
    var profiles = {}
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
        var full = Math.max(a[0], z[0]) - k.l
        var base = Math.min(full, tab.base || 0)
        var d = base + (full - base) * (tab.reveal === undefined ? 1 : tab.reveal)
        var s = Math.min(a[1], z[1]), e = Math.max(a[1], z[1])
        if (d > 0 && e > s)
            bumps[side].push({ d: d, s: s, e: e, k: tab.swell || 1 })
    })

    edges.forEach(function (side) {
        var k = frames[side]
        profiles[side] = profile(bumps[side], k.t, k.h - k.b)
    })

    edges.forEach(function (side, at) {
        var k = frames[side]
        var l = k.l, t = k.t, h = k.h, b = k.b
        var segs = profiles[side]
        function pt(x, y) { var p = turn(side, width, height, x, y); return n(p[0]) + " " + n(p[1]) }
        function line(x, y) { return "L" + pt(x, y) }
        function arc(rad, sweep, x, y) { return "A" + n(rad) + " " + n(rad) + " 0 0 " + sweep + " " + pt(x, y) }

        // A profile that starts at the far end takes the corner into the edge.
        if (segs[0].d > 0) {
            var f0 = Math.min(R * segs[0].k, segs[0].d)
            out.push(line(l + segs[0].d + f0, h - b), arc(f0, 1, l + segs[0].d, h - b - f0))
        }

        // Each step between two segments: up to the deeper one, or back.
        for (var i = 0; i + 1 < segs.length; i++) {
            var from = segs[i], to = segs[i + 1]
            var p = from.s
            var r = Math.min(R * Math.max(from.k, to.k), Math.abs(to.d - from.d) / 2,
                             (from.e - from.s) / 2, (to.e - to.s) / 2)
            if (to.d > from.d)
                out.push(line(l + from.d, p + r), arc(r, 1, l + from.d + r, p),
                         line(l + to.d - r, p), arc(r, 0, l + to.d, p - r))
            else
                out.push(line(l + from.d, p + r), arc(r, 0, l + from.d - r, p),
                         line(l + to.d + r, p), arc(r, 1, l + to.d, p - r))
        }

        var end = segs[segs.length - 1]
        if (end.d > 0) {
            var f1 = Math.min(R * end.k, end.d)
            out.push(line(l + end.d, t + f1), arc(f1, 1, l + end.d + f1, t))
        }

        // The corner into the next edge, unless a profile on either side took it.
        var next = profiles[edges[(at + 1) % 4]]
        if (end.d <= 0 && next[0].d <= 0)
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

// Where a w x h card sits beside `card` (a screen rect), toward the inside of
// the screen from the bar's edge, `gap` clear of it, and along the bar centred
// on `anchor` (a screen point) within the hole's insets like popupAlong.
function besideAt(edge, card, w, h, anchor, hole, gap, width, height) {
    var x = popupAlong(anchor.x, w, hole.left, width - hole.right, false, gap, 0)
    var y = popupAlong(anchor.y, h, hole.top, height - hole.bottom, false, gap, 0)
    switch (edge) {
    case "bottom": return { x: x, y: card.y - gap - h }
    case "left": return { x: card.x + card.width + gap, y: y }
    case "right": return { x: card.x - gap - w, y: y }
    default: return { x: x, y: card.y + card.height + gap }
    }
}

// Where the notification stack sits for a position such as "top-right".
// Docked, flush with the hole, as a tab of the frame on its top or bottom
// edge; floating, a gap inside the space the bar and the frame leave. On an
// islands bar (islands: its screen rects) a stack that overlaps no island
// hangs from the thin frame instead of below the island strip.
function stackRect(position, width, height, w, h, layout, docked, gap, islands) {
    var parts = position.split("-")
    var vertical = parts[0] === "bottom" ? "bottom" : "top"
    var across = parts[1] === "left" || parts[1] === "center" ? parts[1] : "right"
    var bounds = docked ? layout.dock : layout.reserve
    var g = docked ? 0 : gap
    var x = across === "left" ? bounds.left + g
          : across === "right" ? width - bounds.right - g - w
          : bounds.left + (width - bounds.left - bounds.right - w) / 2
    var y = vertical === "top" ? bounds.top + g : height - bounds.bottom - g - h
    if (docked && islands && islands.length > 0 && layout.dock[vertical] > layout.hole[vertical]
            && !islands.some(function (r) { return r.x < x + w && r.x + r.width > x }))
        y = vertical === "top" ? layout.hole.top : height - layout.hole.bottom - h
    return { x: x, y: y, edge: vertical }
}

// --- liquid motion ------------------------------------------------------------
// A popup (or the notification stack) opens like a drop of liquid in glass and
// as a short smooth fade in solid. Both are functions of one timeline t (0
// closed .. 1 open), so the same curves run backwards when it closes, and a
// preview can freeze any frame. p are the tokens of the motion (tokens.js).

function clamp(x, lo, hi) {
    return Math.max(lo, Math.min(hi, x))
}

function outCubic(x) {
    var u = 1 - x
    return 1 - u * u * u
}

function outBack(x, overshoot) {
    var u = x - 1
    return 1 + (overshoot + 1) * u * u * u + overshoot * u * u
}

function smoothstep(x) {
    return x * x * (3 - 2 * x)
}

// What the shape does at time t:
//   reveal  depth of a docked tab, 0..1 with a small spring overshoot
//   grow    the same for a floating card (1 in solid, which only fades)
//   spread  how far its length along the bar has stretched from the button
//   swell   multiplier of the fillet radius (surface tension)
//   pull    extra distance (in gaps) a floating card detaches while moving
//   bond    thickness of the neck that joins a floating card to its bar, 0
//           once it has snapped
//   content opacity of what is inside; it waits for the shape
//   fade, scale, shift   whole-card opacity, scale and slide (px, towards the
//           bar) of the solid motion
//   stretch how far a card in motion reaches ahead of itself (see liquidRect)
function liquid(t, p) {
    var x = clamp(t, 0, 1)
    var bell = Math.sin(Math.PI * clamp(x / p.swellEnd, 0, 1))
    var reveal = outBack(x, p.overshoot)
    return {
        reveal: reveal,
        grow: reveal,
        spread: outCubic(clamp(x / p.spreadEnd, 0, 1)),
        swell: 1 + p.swell * bell,
        pull: p.pull * bell,
        bond: 1 - smoothstep(clamp(x / p.snapAt, 0, 1)),
        content: smoothstep(clamp((x - p.contentAt) / (1 - p.contentAt), 0, 1)),
        fade: 1,
        scale: 1,
        shift: 0,
        stretch: p.stretch
    }
}

function smooth(t, p) {
    var x = clamp(t, 0, 1)
    var eased = outCubic(x)
    return {
        reveal: eased,
        grow: 1,
        spread: 1,
        swell: 1,
        pull: 0,
        bond: 0,
        content: smoothstep(clamp((x - p.contentAt) / (1 - p.contentAt), 0, 1)),
        fade: smoothstep(x),
        scale: p.scale + (1 - p.scale) * eased,
        shift: p.shift * (1 - eased),
        stretch: p.stretch
    }
}

function isVertical(edge) {
    return edge === "left" || edge === "right"
}

// The card rect with its length along the bar (the bar edge) stretched
// `spread` of the way from the button's rect to its own; a card still gliding
// to a new button (lag = where it is going - where it is, px along the bar)
// reaches ahead of itself by lag * stretch. No button: it starts as a point at
// its centre.
function liquidRect(rect, edge, origin, spread, lag, stretch) {
    var v = isVertical(edge)
    var s = v ? rect.y : rect.x, len = v ? rect.height : rect.width
    var from = origin ? (v ? origin.y : origin.x) : s + len / 2
    var fromLen = origin ? (v ? origin.height : origin.width) : 0
    var a = from + (s - from) * spread
    var l = fromLen + (len - fromLen) * spread
    var reach = lag * stretch
    if (reach < 0) {
        a += reach
        l -= reach
    } else {
        l += reach
    }
    return v ? Qt.rect(rect.x, a, rect.width, l) : Qt.rect(a, rect.y, l, rect.height)
}

// A floating card while it moves: `rect` is where it rests, `gap` the distance
// of its near face from the bar's face. Liquid, it leaves the bar face as a
// drop (its depth and distance grow with look.grow, it detaches further than
// rest while look.pull is up); solid, it keeps its size and slides in from the
// bar, scaled down.
function floatRect(rect, edge, origin, look, gap, lag) {
    var v = isVertical(edge)
    var along = liquidRect(rect, edge, origin, look.spread, lag, look.stretch)
    var dir = edge === "right" || edge === "bottom" ? -1 : 1
    var d0 = v ? along.x : along.y
    var dl = v ? along.width : along.height
    var near = dir > 0 ? d0 : d0 + dl
    var face = near - dir * gap
    var start = face + dir * (gap * (look.grow + look.pull) - look.shift)
    var length = Math.max(0, dl * look.grow * look.scale)
    var lo = dir > 0 ? start : start - length
    var a0 = v ? along.y : along.x
    var al = v ? along.height : along.width
    var shrink = al * (1 - look.scale) / 2
    a0 += shrink
    al -= 2 * shrink
    return v ? Qt.rect(lo, a0, length, al) : Qt.rect(a0, lo, al, length)
}

// The liquid neck between the island (or bar) a floating card came out of and
// the card: an hourglass whose waist thins with bond (1 = as wide as the faces
// allow, 0 = snapped). Null when there is no neck to draw. Returns
// { path, sides, waist, width, length }: the closed outline and the two
// concave sides (to stroke the glass edge), in screen coordinates.
function neck(width, height, edge, island, card, bond, radius) {
    if (bond <= 0.01)
        return null
    var side = edges.indexOf(edge) < 0 ? "left" : edge
    function span(r) {
        var a = unturn(side, width, height, r.x, r.y)
        var z = unturn(side, width, height, r.x + r.width, r.y + r.height)
        return { x0: Math.min(a[0], z[0]), x1: Math.max(a[0], z[0]),
                 y0: Math.min(a[1], z[1]), y1: Math.max(a[1], z[1]) }
    }
    var i = span(island), c = span(card)
    var from = i.x1, to = c.x0
    // The neck leaves the straight part of both faces (a corner radius in), or
    // a quarter of the overlap in when the island is narrow.
    var from0 = Math.max(i.y0, c.y0), to0 = Math.min(i.y1, c.y1)
    var inset = Math.min(radius, (to0 - from0) / 4)
    var lo = from0 + inset, hi = to0 - inset
    if (to - from < 0.5 || hi - lo < 1)
        return null
    var mid = (lo + hi) / 2
    var half = (hi - lo) / 2 * (0.5 + 0.5 * bond)
    var waist = half * bond
    var bow = 2 * waist - half
    var centre = (from + to) / 2
    function n(v) { return String(Math.round(v * 100) / 100) }
    function pt(x, y) { var p = turn(side, width, height, x, y); return n(p[0]) + " " + n(p[1]) }
    var upper = "M" + pt(from, mid - half) + " Q" + pt(centre, mid - bow) + " " + pt(to, mid - half)
    var lower = "M" + pt(from, mid + half) + " Q" + pt(centre, mid + bow) + " " + pt(to, mid + half)
    var path = upper + " L" + pt(to, mid + half) + " Q" + pt(centre, mid + bow) + " " + pt(from, mid + half) + " Z"
    return { path: path, sides: [upper, lower], waist: 2 * waist, width: 2 * half, length: to - from }
}

// The rect nearest to a screen point: the one under it, else the closest.
function nearestRect(rects, x, y) {
    var best = null, far = Infinity
    rects.forEach(function (r) {
        var dx = Math.max(r.x - x, 0, x - (r.x + r.width))
        var dy = Math.max(r.y - y, 0, y - (r.y + r.height))
        var d = dx * dx + dy * dy
        if (d < far) {
            far = d
            best = r
        }
    })
    return best
}

// Where a tooltip of w x h sits for a bar element (`target`, a screen rect):
// `offset` past the screen edge (the bar's inner face) plus a gap, on the side
// away from the bar's edge, centred on the element along the bar and kept a
// gap inside the screen.
function tooltipAt(edge, target, w, h, offset, gap, width, height) {
    var along = function (centre, size, extent) {
        return Math.max(gap, Math.min(centre - size / 2, extent - size - gap))
    }
    var x = along(target.x + target.width / 2, w, width)
    var y = along(target.y + target.height / 2, h, height)
    switch (edge) {
    case "bottom": return { x: x, y: height - offset - gap - h }
    case "left": return { x: offset + gap, y: y }
    case "right": return { x: width - offset - gap - w, y: y }
    default: return { x: x, y: offset + gap }
    }
}
