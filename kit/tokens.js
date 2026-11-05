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
    notifications: { min: 1, max: 10, step: 1, value: 5 },
    // The OSD: how long a media key keeps its slider up, how far past the
    // frame its hot zone reaches, and the percent a key or wheel notch moves.
    osdKey: { min: 500, max: 5000, step: 250, value: 2000 },
    osdHot: { min: 0, max: 24, step: 1, value: 5 },
    osdStep: { min: 1, max: 20, step: 1, value: 5 },
    osdBrightnessStep: { min: 1, max: 20, step: 1, value: 5 },
    // The percent one wheel notch moves an app's own volume.
    soundStep: { min: 1, max: 20, step: 1, value: 5 },
    // The audio visualiser's strip: how tall it is in the background.
    visualiserHeight: { min: 48, max: 320, step: 8, value: 120 },
    // The pointer's size in pixels.
    cursor: { min: 16, max: 64, step: 2, value: 24 }
}

// Typography is a scale over the base size the user picks.
var font = {
    // Material: Roboto for text, Material Symbols for icons (by ligature
    // name, e.g. "wifi").
    family: "Roboto",
    icons: "Material Symbols Rounded",
    // The three families the shell may draw its ligatures from; any other
    // value falls back to `icons`.
    iconVariants: {
        rounded: "Material Symbols Rounded",
        sharp: "Material Symbols Sharp",
        outlined: "Material Symbols Outlined"
    },
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

// The family for a stored variant key; an unknown key keeps the default so a
// stale preference never asks for a font that would draw plain text.
font.iconFamilyOf = function (key) {
    // Own keys only: "constructor" and "__proto__" exist on every object and
    // are not variants.
    if (Object.prototype.hasOwnProperty.call(font.iconVariants, key))
        return font.iconVariants[key]
    return font.icons
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
    // How often the bell re-reads a silence that has an end, so the tooltip's
    // "X min left" follows the clock.
    minute: 60000,
    // How long the pointer must rest on a hot zone before its panel opens.
    dwell: 150,
    // How long typing in a menu keeps building the same search.
    typeahead: 800,
    // How often the Connection page looks for the answer to a request, and how
    // long it waits for one before it gives up. `probe` is how often the VPN
    // tab measures its connections while it is open and `probeWait` how long a
    // request made meanwhile waits for it; `settle` how long a
    // password file gets to reach the disk before the request that names it.
    poll: 1500,
    patience: 90000,
    probe: 60000,
    probeWait: 20000,
    settle: 150,
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
    // A hairline progress track.
    thin: 3,
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

// The media player (bar/media). Lengths are px, times ms.
// disc: `size` of the cover, `pad` of room around it for the ring, `marks`
// dashes in the ring, `gap` from the cover to the ring, `dot` the mark's
// thickness and its length when paused (a dotted border), `longest` how far a
// mark grows while playing, `idle` / `low` the mark opacity when paused / at
// its shortest while playing, `settle` how long the ring takes to change
// between dots and bars, `bounce` one bounce of the bars, `turn` one revolution
// of the record, `hole` the spindle hole, `label` the label circle's diameter
// and `labelMin` the smallest text in it. The record is `vinyl` times darker
// than the theme's dark tone, with `grooves` (radii in px) drawn at the
// `groove` opacity of the light tone and an `edge` outline `edgeWidth` px
// wide. The tonearm has its pivot at `armAngle` degrees around the record,
// `armReach` of the radius out, and its head at `headAngle` / `headReach`;
// `arm` is its thickness, `pivot` the base's diameter, `headLength` /
// `headWidth` the head and `armTone` its opacity.
// cassette: every number is px of a tape 80 wide (the preview scales it).
// progress: the wave drawn over the shell slider's filled part (the slider's
// own size sets the thickness): `amplitude` and `wavelength`, `period` ms a wave
// takes to travel one wavelength (calm), `settle` ms the wave takes to fade
// and ease in or out when playback changes, `step` px between wave samples.
// panel: the card's content `width`.
// chip: the application chip and its list: `icon` / `rowIcon` app icon sizes,
// `nameMax` the widest a name gets before it scrolls (a shorter one takes its
// own width), `padY` vertical padding of the chip, `row` height of a list
// entry, `rest` / `open` / `current` the fill opacity of the chip, of
// the open chip and of the current entry, `listRadius` / `rowRadius` the list's
// and an entry's corners as a fraction of the shell radius, `listGap` between
// entries.
// preview: the settings tile's room for a look, and how much it is scaled.
var media = {
    disc: {
        size: 68,
        pad: 13,
        marks: 36,
        gap: 2,
        dot: 3,
        longest: 11,
        idle: 0.6,
        low: 0.4,
        settle: 420,
        bounce: 1200,
        turn: 8000,
        hole: 6,
        label: 40,
        labelMin: 6,
        vinyl: 6,
        grooves: [32, 29, 26, 23],
        groove: 0.14,
        edge: 0.35,
        edgeWidth: 1,
        armAngle: -48,
        armReach: 0.92,
        headAngle: 22,
        headReach: 0.7,
        arm: 2,
        pivot: 6,
        headLength: 8,
        headWidth: 4,
        armTone: 0.9
    },
    cassette: {
        width: 80,
        height: 52,
        radius: 5,
        deepen: 1.5,
        textMin: 5,
        edge: 0.2,
        edgeWidth: 1,
        screwTone: 0.6,
        lineTone: 0.45,
        screw: 3,
        screwAt: 3,
        labelX: 9,
        labelY: 5,
        labelWidth: 62,
        labelHeight: 30,
        labelRadius: 2,
        letter: 13,
        letterX: 2,
        letterY: -1,
        lineX: 17,
        lineY: 3,
        lineStep: 3,
        lineWidth: 36,
        lineShort: 24,
        bandPrimary: 3,
        bandSecondary: 1,
        windowX: 18,
        windowY: 16,
        windowWidth: 44,
        windowHeight: 14,
        windowRadius: 4,
        reel: 11,
        hub: 6,
        teeth: 6,
        tooth: 1.5,
        stripHeight: 1.5,
        taper: 2,
        turn: 2500,
        baseY: 37,
        baseInset: 12,
        baseTaper: 5,
        baseHeight: 13,
        hole: 4,
        holeAt: 21,
        slot: 3,
        slotAt: 10
    },
    progress: {
        amplitude: 3,
        wavelength: 30,
        period: 5000,
        settle: 420,
        step: 2
    },
    panel: {
        width: 360
    },
    chip: {
        icon: 14,
        rowIcon: 16,
        nameMax: 96,
        padY: 3,
        row: 26,
        rest: 0.07,
        open: 0.12,
        current: 0.16,
        listRadius: 0.6,
        rowRadius: 0.4,
        listGap: 2
    },
    preview: {
        width: 64,
        height: 56,
        disc: 0.6,
        cassette: 0.75
    }
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

// The tray (bar/tray): `columns` the most icons per row in the popup style,
// `menu` the width of an app's menu card, `dot` the attention dot, px.
var tray = {
    columns: 4,
    menu: 300,
    dot: 6
}

// The audio visualiser (bar/shell.qml background layer): `bars` is cava's
// count, `coverage` the bar's share of its cell (the rest is the gap), `floor`
// the smallest bar as a fraction of the height, `width` / `maxWidth` the strip
// relative to the screen, and `smoothing` ms each bar takes to follow a new
// level. Reflection stands the bars on `baseline` of the height, mirrors them
// below it at `fade` opacity and `reach` of their height. The panel gives the
// strip a surface with `padding` (a gap step), `radius` times the shell radius
// and `width` of the screen.
var visualiser = {
    bars: 64,
    coverage: 0.52,
    floor: 0.04,
    width: 0.66,
    maxWidth: 1280,
    smoothing: 90,
    reflection: { baseline: 0.72, fade: 0.28, reach: 0.62, gap: 2 },
    panel: { padding: "lg", radius: 1.5, width: 0.72 }
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
