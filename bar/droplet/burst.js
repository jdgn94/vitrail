// The droplet's closing burst: a ring of small drops that leave the last rect
// and fade. Pure, so the angles, sizes and end times can be tested; the values
// (count, reach, duration) come from kit/tokens.js.
.pragma library

function number(value, fallback) {
    var parsed = Number(value)
    return isFinite(parsed) ? parsed : fallback
}

// A deterministic ring, not random: `count` droplets spread around the centre,
// their sizes and distances varied so the burst does not look stamped. Every
// particle has finished by `duration` (its own span is shortened by its delay).
function particles(count, reach, duration, size) {
    var total = Math.max(1, number(duration, 250))
    var base = Math.max(0, number(reach, 0))
    var dot = Math.max(1, number(size, 7))
    var n = Math.max(0, Math.min(24, Math.round(number(count, 0))))
    var out = []
    for (var i = 0; i < n; i++) {
        var step = 360 / n
        var angle = (i * step + 11 + (i % 2) * 13) * Math.PI / 180
        var delay = Math.round(total * 0.12 * (i % 3))
        out.push({
            angle: angle,
            size: Math.round(dot * (0.55 + 0.35 * (1 + Math.sin(i * 1.7)) / 2) * 100) / 100,
            distance: Math.round(base * (0.55 + 0.45 * (1 + Math.cos(i * 1.3)) / 2) * 100) / 100,
            delay: delay,
            duration: Math.max(1, total - delay)
        })
    }
    return out
}

// Where a ray from the rect's centre at `angle` (radians) leaves it: the ring
// starts on the closing window's edge, not inside the window that is fading.
function edge(rect, angle) {
    var w = Math.max(0, number(rect && rect.width, 0))
    var h = Math.max(0, number(rect && rect.height, 0))
    var cx = number(rect && rect.x, 0) + w / 2
    var cy = number(rect && rect.y, 0) + h / 2
    var dx = Math.cos(angle)
    var dy = Math.sin(angle)
    var tx = Math.abs(dx) > 1e-9 ? (w / 2) / Math.abs(dx) : Infinity
    var ty = Math.abs(dy) > 1e-9 ? (h / 2) / Math.abs(dy) : Infinity
    var t = Math.min(tx, ty)
    return { x: cx + dx * t, y: cy + dy * t }
}
