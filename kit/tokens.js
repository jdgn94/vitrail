// Design tokens: the only place with literal numbers.
//
// Every value the user can tune declares min / max / step so the settings
// panel can build a slider from it without hardcoding ranges in QML.
.pragma library

var ranges = {
    spacing: { min: 0, max: 32, step: 1, value: 12 },
    radius: { min: 0, max: 32, step: 1, value: 14 },
    blur: { min: 0, max: 12, step: 1, value: 6 },
    opacity: { min: 0.30, max: 1.00, step: 0.01, value: 0.90 },
    // Screen frame thickness, system bar thickness and side panel depth.
    frame: { min: 0, max: 24, step: 1, value: 6 },
    bar: { min: 24, max: 64, step: 1, value: 36 },
    panel: { min: 240, max: 720, step: 8, value: 384 },
    // Notifications on screen at once; the rest wait their turn.
    notifications: { min: 1, max: 10, step: 1, value: 5 }
}

// Typography is a scale over the base size the user picks.
var font = {
    // Material: Roboto for text, Material Symbols for icons (by ligature
    // name, e.g. "wifi").
    family: "Roboto",
    icons: "Material Symbols Rounded",
    min: 10,
    max: 22,
    step: 1,
    base: 13,
    scale: {
        display: 2.40,
        title: 1.70,
        subtitle: 1.30,
        body: 1.00,
        content: 0.95,
        label: 0.85
    }
}

// Motion travels with the variant, not with the component.
var motion = {
    fast: 120,
    base: 180,
    slow: 260,
    easing: "outCubic"
}

// Slider track thickness per size; the handle and the gaps around it.
var slider = {
    sm: 8,
    md: 16,
    lg: 28,
    handle: 4,
    gap: 4
}

var space = {
    xs: 0.35,
    sm: 0.6,
    md: 1.0,
    lg: 1.6,
    xl: 2.4
}

function size(name) {
    return Math.round(font.base * (font.scale[name] || 1))
}

function gap(name) {
    return Math.round(ranges.spacing.value * (space[name] || 1))
}

function duration(name) {
    return motion[name] || motion.base
}
