// The colour tab's rules: reading a hex, writing it in every format, and the
// last colours. Tested in tests/qml/tst_colors.qml.
.pragma library

// The formats the selector offers, in order.
var FORMATS = ["hex", "hex8", "rgb", "rgba", "hsl", "hsla"]

// How many colours the tab remembers.
var RECENT = 10

// "#rgb", "#rrggbb" or "#rrggbbaa" (the # optional) → { r, g, b, a } in 0..255.
function parse(text) {
    var value = String(text || "").trim().replace(/^#/, "")
    if (!/^[0-9a-f]{3}$|^[0-9a-f]{6}$|^[0-9a-f]{8}$/i.test(value))
        return null
    if (value.length === 3)
        value = value[0] + value[0] + value[1] + value[1] + value[2] + value[2]
    return {
        r: parseInt(value.slice(0, 2), 16),
        g: parseInt(value.slice(2, 4), 16),
        b: parseInt(value.slice(4, 6), 16),
        a: value.length === 8 ? parseInt(value.slice(6, 8), 16) : 255
    }
}

function isColor(text) {
    return parse(text) !== null
}

function hex2(value) {
    var text = Math.max(0, Math.min(255, Math.round(value))).toString(16).toUpperCase()
    return text.length < 2 ? "0" + text : text
}

function alpha(color) {
    return String(Math.round((color.a / 255) * 100) / 100)
}

// r/g/b → { h: 0..360, s: 0..100, l: 0..100 }, rounded.
function toHsl(r, g, b) {
    var rr = r / 255
    var gg = g / 255
    var bb = b / 255
    var max = Math.max(rr, gg, bb)
    var min = Math.min(rr, gg, bb)
    var l = (max + min) / 2
    if (max === min)
        return { h: 0, s: 0, l: Math.round(l * 100) }
    var d = max - min
    var s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    var h
    if (max === rr)
        h = (gg - bb) / d + (gg < bb ? 6 : 0)
    else if (max === gg)
        h = (bb - rr) / d + 2
    else
        h = (rr - gg) / d + 4
    return { h: Math.round(h * 60), s: Math.round(s * 100), l: Math.round(l * 100) }
}

// The colour in one of FORMATS.
function format(color, kind) {
    if (!color)
        return ""
    var r = color.r
    var g = color.g
    var b = color.b
    if (kind === "hex8")
        return "#" + hex2(r) + hex2(g) + hex2(b) + hex2(color.a)
    if (kind === "rgb")
        return "rgb(" + r + ", " + g + ", " + b + ")"
    if (kind === "rgba")
        return "rgba(" + r + ", " + g + ", " + b + ", " + alpha(color) + ")"
    var hsl = toHsl(r, g, b)
    if (kind === "hsl")
        return "hsl(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%)"
    if (kind === "hsla")
        return "hsla(" + hsl.h + ", " + hsl.s + "%, " + hsl.l + "%, " + alpha(color) + ")"
    return "#" + hex2(r) + hex2(g) + hex2(b)
}

// The stored preference as a list: a JSON array of hex values, cleaned.
function recentFrom(text) {
    var value = String(text || "").trim()
    if (value === "")
        return []
    try {
        var list = JSON.parse(value)
        if (!Array.isArray(list))
            return []
        return list.filter(isColor).slice(0, RECENT)
    } catch (error) {
        return []
    }
}

// The list with `hex` at the top, without repeats, capped at `max`.
function addRecent(list, hex, max) {
    var value = String(hex || "").trim().toUpperCase()
    if (!isColor(value))
        return list
    var cap = max || RECENT
    var out = [value]
    for (var i = 0; i < list.length && out.length < cap; i++) {
        if (String(list[i]).toUpperCase() !== value)
            out.push(list[i])
    }
    return out
}
