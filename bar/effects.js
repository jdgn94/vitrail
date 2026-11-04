// The wallpaper effects: the names vitrail/effects.py knows and the checks the
// settings window and the bar need. It mirrors RECIPES there, and
// tests/test_effects.py fails when the two lists drift apart.
.pragma library

var NAMES = [
    "none", "b&w", "blur", "charcoal", "edge", "emboss", "raise", "sunken", "negate",
    "paint", "posterize", "polaroid", "sepia", "solarize", "sharpen", "vignette",
    "vignette-black", "zoomed"
]

var IMAGE = /\.(png|jpe?g|webp|bmp)$/i

// Whether a picture (not an SVG or a video) can take an effect.
function isImage(path) {
    return IMAGE.test(String(path || ""))
}

// Whether `name` is one of the recipes (an unknown name means the original).
function known(name) {
    return NAMES.indexOf(name) >= 0
}

// A stored preference as an effect: missing, empty and unknown read as "none".
function of(raw) {
    return known(raw) && raw !== undefined ? raw : "none"
}

// The stable copy apply-settings writes for the bar: one for the whole screen,
// or one per output (vitrail/effects.py:shown names them the same way).
var SHOWN = "wallpaper-effect.png"

function shown(output) {
    if (!output)
        return SHOWN
    return "wallpaper-effect-" + String(output).replace(/[^A-Za-z0-9._-]/g, "_") + ".png"
}
