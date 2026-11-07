// cava's frame numbers for the audio visualiser. No QML type is touched here:
// `tests/qml/tst_visualiser.qml` feeds it plain strings, arrays and documents.
.pragma library

var MAX_RANGE = 100

// One cava value: a number on the 0..100 scale, never negative or out of
// range; anything unreadable is silence.
function number(value) {
    var numeric = Number(value)
    if (isNaN(numeric) || !isFinite(numeric) || numeric < 0)
        return 0
    return Math.min(MAX_RANGE, numeric)
}

function listOf(source) {
    if (source === undefined || source === null)
        return []
    if (typeof source === "string")
        return source.split(/[;,\s]+/)
    if (Object.prototype.hasOwnProperty.call(source, "values"))
        return source.values
    if (source.length !== undefined)
        return source
    return []
}

// Exactly `count` values: a short frame is padded with silence and a long one
// is cut, so every bar always has a number.
function values(source, count) {
    var list = listOf(source)
    var total = Math.max(1, Math.floor(count || 0))
    var out = []
    for (var i = 0; i < total; i++)
        out.push(number(list[i]))
    return out
}

// A value as a 0..1 bar height.
function level(value) {
    return number(value) / MAX_RANGE
}

// The circle look: one radial bar per level, standing around the centre and
// growing outward. Angles start at the top and run clockwise. `ring` is the
// visualiser.circle token block: `radius` is the reach as a share of the
// strip's half height, `inner` where a bar starts on that reach, and
// `coverage` the share of its angular cell the bar keeps. `floor` is the
// smallest bar, as a share of the reach. Every bar reports the centre of its
// unrotated box (`x`, `y`), its `length`, `thickness` and `rotation`.
function radial(source, count, width, height, ring, floor) {
    var levels = values(source, count)
    var total = Math.max(1, Math.floor(count || 0))
    var centreX = width / 2
    var centreY = height / 2
    var reach = Math.min(width, height) / 2 * ring.radius
    var start = reach * ring.inner
    var cell = Math.PI * 2 / total
    var middle = (start + reach) / 2
    var thickness = Math.max(1, cell * middle * ring.coverage)
    var out = []
    for (var i = 0; i < total; i++) {
        var angle = -Math.PI / 2 + i * cell
        var length = Math.max((floor || 0) * reach,
                              level(levels[i]) * (reach - start))
        var mid = start + length / 2
        out.push({
            x: centreX + Math.cos(angle) * mid,
            y: centreY + Math.sin(angle) * mid,
            length: length,
            thickness: thickness,
            rotation: angle * 180 / Math.PI - 90
        })
    }
    return out
}

// The waves look: `wave.lines` polylines across the strip, each sampling
// `count` levels. `wave` is the visualiser.waves token block: `amplitude` of
// the strip height, `spread` the distance between lines, and `lines` the
// count. Each line's samples run left to right, `count` points, last one on
// the far edge.
function wave(source, count, width, height, wave) {
    var levels = values(source, count)
    var total = Math.max(1, Math.floor(count || 0))
    var lines = Math.max(1, Math.floor(wave.lines || 0))
    var out = []
    for (var l = 0; l < lines; l++) {
        var points = []
        var baseline = height * (0.5 + (l - (lines - 1) / 2) * wave.spread)
        for (var i = 0; i < total; i++) {
            var x = total === 1 ? 0 : width * i / (total - 1)
            var y = baseline - (level(levels[i]) - 0.5) * 2 * height * wave.amplitude
            points.push({ x: x, y: y })
        }
        out.push(points)
    }
    return out
}
