// Drawing copied HTML with Qt's rich text: the CSS a source leaves in `style`
// reduced to what QML's Text understands. The HTML arrives already sanitized
// (vitrail/richclip.py: an allow-list of tags and properties, one normal form),
// so this only rewrites values: lengths to px, colours to hex, sizes capped
// and scaled so a poster-sized copy still fits the preview card.
// Tested in tests/qml/tst_clipboard.qml.
.pragma library

var BASE = 16
var KEYWORDS = { "xx-small": 9, "x-small": 10, small: 13, medium: 16, large: 18, "x-large": 24, "xx-large": 32 }
var NAMES = { black: [0, 0, 0], white: [255, 255, 255], gray: [128, 128, 128], grey: [128, 128, 128],
              silver: [192, 192, 192], red: [255, 0, 0], green: [0, 128, 0], blue: [0, 0, 255] }

function hex(value) {
    return ("0" + Math.max(0, Math.min(255, Math.round(value))).toString(16)).slice(-2)
}

// "#rgb", "#rrggbb", "rgb(r, g, b)", "rgba(r, g, b, a)" or a few names → { r, g, b, a } or null.
function parseColor(text) {
    var value = String(text || "").trim().toLowerCase()
    var match = /^#([0-9a-f]{3})$/.exec(value)
    if (match)
        return { r: parseInt(match[1][0] + match[1][0], 16), g: parseInt(match[1][1] + match[1][1], 16),
                 b: parseInt(match[1][2] + match[1][2], 16), a: 1 }
    match = /^#([0-9a-f]{6})$/.exec(value)
    if (match)
        return { r: parseInt(match[1].slice(0, 2), 16), g: parseInt(match[1].slice(2, 4), 16),
                 b: parseInt(match[1].slice(4, 6), 16), a: 1 }
    match = /^rgba?\(\s*([\d.]+)[\s,]+([\d.]+)[\s,]+([\d.]+)(?:[\s,/]+([\d.]+%?))?\s*\)$/.exec(value)
    if (match) {
        var alpha = match[4] === undefined ? 1 : (match[4].slice(-1) === "%" ? parseFloat(match[4]) / 100 : parseFloat(match[4]))
        return { r: Number(match[1]), g: Number(match[2]), b: Number(match[3]), a: alpha }
    }
    if (NAMES[value])
        return { r: NAMES[value][0], g: NAMES[value][1], b: NAMES[value][2], a: 1 }
    return null
}

// A colour Qt draws: opaque hex, or "" when there is none to draw (transparent,
// unknown). Translucent colours keep their rgb: the card has no page to blend with.
function color(text) {
    var parsed = parseColor(text)
    if (!parsed || parsed.a <= 0)
        return ""
    return "#" + hex(parsed.r) + hex(parsed.g) + hex(parsed.b)
}

// 0 (black) .. 1 (white).
function luminance(parsed) {
    return (0.2126 * parsed.r + 0.7152 * parsed.g + 0.0722 * parsed.b) / 255
}

// A length in px (`reference` is the size em and % refer to), or -1.
function px(text, reference) {
    var value = String(text || "").trim().toLowerCase()
    if (KEYWORDS[value] !== undefined)
        return KEYWORDS[value]
    if (value === "smaller")
        return reference / 1.2
    if (value === "larger")
        return reference * 1.2
    var match = /^(-?[\d.]+)(px|pt|em|rem|%|ex)?$/.exec(value)
    if (!match)
        return -1
    var amount = parseFloat(match[1])
    var unit = match[2] || "px"
    if (unit === "pt")
        return amount * 4 / 3
    if (unit === "em")
        return amount * reference
    if (unit === "rem")
        return amount * BASE
    if (unit === "%")
        return amount * reference / 100
    if (unit === "ex")
        return amount * reference / 2
    return amount
}

function round(value) {
    return Math.round(value * 10) / 10
}

// One declaration → the declaration Qt understands, or "" to drop it.
function declare(name, value, scale, maxSize) {
    var setting = String(value || "").trim()
    if (name === "color" || name === "background-color") {
        var tone = color(setting)
        return tone === "" ? "" : name + ": " + tone
    }
    if (name === "font-size") {
        var size = px(setting, BASE)
        return size > 0 ? "font-size: " + round(Math.max(6, Math.min(maxSize, size * scale))) + "px" : ""
    }
    if (name === "font-weight") {
        if (setting === "bolder")
            return "font-weight: bold"
        if (setting === "lighter")
            return "font-weight: normal"
        return /^(normal|bold|[1-9]00)$/.test(setting) ? "font-weight: " + setting : ""
    }
    if (name === "font-style")
        return /^(italic|oblique)$/.test(setting) ? "font-style: italic" : (setting === "normal" ? "font-style: normal" : "")
    if (name === "font-family")
        return setting === "" ? "" : "font-family: " + setting
    if (name === "letter-spacing" || name === "word-spacing") {
        var gap = px(setting, BASE)
        return gap >= -4 && gap <= 40 ? name + ": " + round(gap * scale) + "px" : ""
    }
    if (name === "line-height") {
        if (setting === "normal")
            return ""
        if (/^[\d.]+$/.test(setting))
            return "line-height: " + Math.round(parseFloat(setting) * 100) + "%"
        if (/%$/.test(setting))
            return "line-height: " + setting
        var height = px(setting, BASE)
        return height > 0 ? "line-height: " + round(height * scale) + "px" : ""
    }
    if (name === "text-decoration") {
        var kind = /underline|line-through|none/.exec(setting)
        return kind ? "text-decoration: " + kind[0] : ""
    }
    if (name === "text-align")
        return /^(left|right|center|justify)$/.test(setting) ? "text-align: " + setting : ""
    if (name.indexOf("margin-") === 0 || name === "text-indent") {
        var length = px(setting, BASE)
        return length >= 0 && length <= 96 ? name + ": " + round(length * scale) + "px" : ""
    }
    if (name === "list-style-type")
        return /^[a-z-]+$/.test(setting) ? name + ": " + setting : ""
    if (name === "white-space")
        return /^(pre|pre-wrap|nowrap|normal)$/.test(setting) ? name + ": " + setting : ""
    return ""
}

// The style attribute of one tag, reduced.
function reduceStyle(style, scale, maxSize) {
    var out = []
    String(style || "").split(";").forEach(function (declaration) {
        var colon = declaration.indexOf(":")
        if (colon < 0)
            return
        var rule = declare(declaration.slice(0, colon).trim().toLowerCase(), declaration.slice(colon + 1), scale, maxSize)
        if (rule !== "")
            out.push(rule)
    })
    return out.join("; ")
}

// The biggest font-size (px) the HTML asks for, 0 if none.
function largest(html) {
    var big = 0
    var pattern = /font-size:\s*([^;"]+)/g
    var found
    while ((found = pattern.exec(String(html || ""))) !== null) {
        var size = px(found[1], BASE)
        if (size > big)
            big = size
    }
    return big
}

// The HTML ready for a Text with `RichText`: every style reduced, the sizes
// scaled by `scale` and none above `maxSize`.
function map(html, scale, maxSize) {
    var factor = scale > 0 ? scale : 1
    return String(html || "").replace(/\sstyle="([^"]*)"/g, function (whole, style) {
        var reduced = reduceStyle(style.replace(/&#x27;|&#39;|&quot;/g, "'"), factor, maxSize)
        return reduced === "" ? "" : ' style="' + reduced.replace(/"/g, "'") + '"'
    })
}

// `map` with the scale that brings the biggest font down to `maxSize`.
function fit(html, maxSize) {
    var big = largest(html)
    return map(html, big > maxSize ? maxSize / big : 1, maxSize)
}

// What the text colours say about the page they were written for: "light" when
// they are mostly dark (they want a light page), "dark" when mostly light, ""
// when the HTML sets none or they are mixed.
function backdrop(html) {
    var pattern = /(?:^|[;"\s])color:\s*([^;"]+)/g
    var found
    var total = 0
    var count = 0
    while ((found = pattern.exec(String(html || ""))) !== null) {
        var parsed = parseColor(found[1])
        if (!parsed || parsed.a <= 0)
            continue
        total += luminance(parsed)
        count += 1
    }
    if (count === 0)
        return ""
    var mean = total / count
    return mean < 0.4 ? "light" : (mean > 0.7 ? "dark" : "")
}
