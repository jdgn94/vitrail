// Colour maths of the kit's colour picker, free of QML: hex codes, hue /
// saturation / lightness, and where a hue and saturation sit on the wheel.
// Pure, tested in tests/qml/tst_color.qml.
.pragma library

var HEX = /^#[0-9a-fA-F]{6}$/

function isHex(text) {
    return typeof text === "string" && HEX.test(text)
}

// "#A1B2C3", "A1B2C3", "#abc" or " abc " as "#a1b2c3" (a short code doubles each
// digit); "" for anything else.
function normalizeHex(text) {
    var value = String(text === undefined || text === null ? "" : text).trim()
    if (value[0] !== "#")
        value = "#" + value
    if (/^#[0-9a-fA-F]{3}$/.test(value))
        value = "#" + value[1] + value[1] + value[2] + value[2] + value[3] + value[3]
    return isHex(value) ? value.toLowerCase() : ""
}

// Channels in 0..1 as "#rrggbb".
function hexOf(red, green, blue) {
    var parts = [red, green, blue].map(function (channel) {
        var part = Math.round(Math.max(0, Math.min(1, channel)) * 255).toString(16)
        return part.length < 2 ? "0" + part : part
    })
    return "#" + parts.join("")
}

// h in degrees, s and l in 0..1.
function hslToHex(h, s, l) {
    var chroma = (1 - Math.abs(2 * l - 1)) * s
    var sector = (((h % 360) + 360) % 360) / 60
    var second = chroma * (1 - Math.abs(sector % 2 - 1))
    var rgb = [[chroma, second, 0], [second, chroma, 0], [0, chroma, second],
               [0, second, chroma], [second, 0, chroma], [chroma, 0, second]][Math.floor(sector) % 6]
    var base = l - chroma / 2
    return hexOf(rgb[0] + base, rgb[1] + base, rgb[2] + base)
}

function hexToHsl(hex) {
    var red = parseInt(hex.slice(1, 3), 16) / 255
    var green = parseInt(hex.slice(3, 5), 16) / 255
    var blue = parseInt(hex.slice(5, 7), 16) / 255
    var top = Math.max(red, green, blue)
    var bottom = Math.min(red, green, blue)
    var l = (top + bottom) / 2
    var spread = top - bottom
    if (spread === 0)
        return { h: 0, s: 0, l: l }
    var s = spread / (1 - Math.abs(2 * l - 1))
    var h
    if (top === red)
        h = ((green - blue) / spread) % 6
    else if (top === green)
        h = (blue - red) / spread + 2
    else
        h = (red - green) / spread + 4
    return { h: (h * 60 + 360) % 360, s: s, l: l }
}

// The wheel: the hue is the angle (0 to the right, growing clockwise on
// screen, so y points down) and the saturation the distance from the centre, 0
// at the centre and 1 at `radius`. The same convention as kit/shaders/color-wheel.frag.

// The hue and saturation under a point given from the wheel's centre; beyond
// the rim it is the rim.
function wheelAt(x, y, radius) {
    var angle = Math.atan2(y, x) * 180 / Math.PI
    return { h: (angle + 360) % 360, s: Math.min(1, Math.sqrt(x * x + y * y) / radius) }
}

// Where a hue and saturation sit, from the wheel's centre.
function wheelPoint(h, s, radius) {
    var angle = h * Math.PI / 180
    return { x: Math.cos(angle) * s * radius, y: Math.sin(angle) * s * radius }
}
