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
    // Caret blink, one turn of a busy indicator, and how long it keeps a shape.
    blink: 530,
    spin: 2400,
    cycle: 650,
    // Hover time before a tooltip appears.
    tooltip: 500,
    // How long the pointer must rest on a hot zone before its panel opens.
    dwell: 150,
    // How long typing in a menu keeps building the same search.
    typeahead: 800,
    // Typing pauses this long before a search runs; a search that never
    // answers is given up after `timeout`.
    debounce: 220,
    timeout: 6000,
    easing: "outCubic"
}

// How popups and the notification stack open (see frame.js liquid / smooth).
// Glass: a drop of liquid. open / close are ms for the whole timeline; the
// rest are fractions of it (spreadEnd, swellEnd, snapAt, contentAt) or
// ratios: overshoot of the spring, swell of the fillets, pull of a floating
// card in gaps, stretch of a card gliding to another button.
motion.liquid = {
    open: 460,
    close: 280,
    overshoot: 1.1,
    spreadEnd: 0.7,
    swellEnd: 0.8,
    swell: 0.9,
    pull: 0.9,
    snapAt: 0.45,
    contentAt: 0.55,
    stretch: 0.12
}

// Solid: a short fade and slide from the bar, no overshoot (shift in px).
motion.smooth = {
    open: motion.base,
    close: motion.fast,
    contentAt: 0.4,
    scale: 0.96,
    shift: 6,
    stretch: 0
}

// Text field: box height per size, and the password shape as a fraction of
// the font size.
var field = {
    height: { sm: 40, md: 52, lg: 64 },
    shape: 0.9
}

// Slider track thickness per size; the handle and the gaps around it.
var slider = {
    sm: 8,
    md: 16,
    lg: 28,
    handle: 4,
    gap: 4,
    // How tall a vertical slider is when nothing sizes it.
    length: 160,
    // Wheel scrolling: angle units and touchpad pixels that make one notch.
    wheelAngle: 120,
    wheelPixels: 60
}

// The OSD of volume, microphone and brightness (bar/osd). `size` is the
// slider's, `length` how long each is, `hot` how far the invisible hot zone
// reaches past the frame border, `hide` and `extension` the pointer's grace
// before the panel and its device card go, `key` how long a media key keeps
// its slider up, `step` the percent a key press (or a wheel notch) moves, `write` how long a
// slider drag waits before it reaches the monitor, `card` the device card's
// width, `stale` how long a brightness reading is trusted.
var osd = {
    size: "md",
    length: 120,
    hot: 5,
    hide: 600,
    extension: 250,
    key: 2000,
    step: 5,
    write: 150,
    stale: 10000,
    card: 300
}

// The application launcher, in its two presentations (see the `launcher`
// variants): `popout` is the compact card under the bar, `fullscreen` the
// screen-wide one. Each: size of the card, columns and minimum cell width of
// the app grid, icon sizes, and for fullscreen the widest the content gets
// (`content`), the narrower width of the field and the lists (`narrow`) and
// the margin around it in `gap("lg")` steps. `expand` is the fraction of the
// screen the popout takes when expanded.
var launcher = {
    maxFiles: 30,
    expand: 0.8,
    popout: {
        width: 640,
        height: 560,
        columns: 6,
        tileMin: 104,
        tileIcon: 44,
        rowIcon: 32,
        content: 0,
        narrow: 0,
        margin: 0
    },
    fullscreen: {
        width: 0,
        height: 0,
        columns: 6,
        tileMin: 148,
        tileIcon: 72,
        rowIcon: 40,
        content: 1320,
        narrow: 800,
        margin: 3
    }
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
