pragma Singleton
import QtQuick
import "tokens.js" as Tokens

// Resolves design tokens for the active theme and the user's scalars.
// main.qml calls configure() whenever the palette or a preference changes.
QtObject {
    id: root

    property var palette: ({})
    property bool dark: true
    property string surfaceMode: "glass"

    // User-tunable values, mirrored from the preference files.
    property real spacing: Tokens.ranges.spacing.value
    property real radius: Tokens.ranges.radius.value
    property real blur: Tokens.ranges.blur.value
    property real opacity: Tokens.ranges.opacity.value
    property real fontBase: Tokens.font.base
    property string fontFamily: Tokens.font.family
    property string iconFamily: Tokens.font.icons
    property real frame: Tokens.ranges.frame.value
    property real bar: Tokens.ranges.bar.value
    property real panel: Tokens.ranges.panel.value

    readonly property var ranges: Tokens.ranges
    readonly property var font: Tokens.font
    readonly property var motion: Tokens.motion
    readonly property var slider: Tokens.slider
    readonly property var osd: Tokens.osd
    readonly property var field: Tokens.field
    readonly property var launcher: Tokens.launcher
    readonly property var media: Tokens.media
    readonly property var tray: Tokens.tray
    readonly property var visualiser: Tokens.visualiser
    readonly property bool glass: root.surfaceMode === "glass"

    function configure(palette, dark, surfaceMode, values) {
        root.palette = palette || ({})
        root.dark = dark === undefined ? true : dark
        root.surfaceMode = surfaceMode || "glass"
        var source = values || ({})
        if (source.spacing !== undefined)
            root.spacing = source.spacing
        if (source.radius !== undefined)
            root.radius = source.radius
        if (source.blur !== undefined)
            root.blur = source.blur
        if (source.opacity !== undefined)
            root.opacity = source.opacity
        if (source.fontBase !== undefined)
            root.fontBase = source.fontBase
        if (source.fontFamily !== undefined)
            root.fontFamily = source.fontFamily
        if (source.iconFamily !== undefined)
            root.iconFamily = source.iconFamily
        if (source.frame !== undefined)
            root.frame = source.frame
        if (source.bar !== undefined)
            root.bar = source.bar
        if (source.panel !== undefined)
            root.panel = source.panel
    }

    function color(role, fallback) {
        var value = root.palette ? root.palette[role] : undefined
        return value === undefined ? fallback : value
    }

    // An opaque fill: `source` (a palette role or a colour) at `amount`,
    // composited over `base` (a role or a colour; the popup card's "surface"
    // by default). Over the blurred glass a translucent fill smears into a
    // dark inner edge; this one is opaque, so its edge is crisp. A shape that
    // must vanish at rest is hidden (`visible`), not drawn at amount 0: that
    // would be an opaque patch of card colour over translucent glass.
    function solid(source, amount, base) {
        var under = base === undefined ? root.color("surface", "transparent") : root.resolve(base)
        return Qt.tint(under, Qt.alpha(root.resolve(source), amount))
    }

    function resolve(source) {
        var value = typeof source === "string" && root.palette ? root.palette[source] : undefined
        return value === undefined ? source : value
    }

    function size(name) {
        return Math.round(root.fontBase * (Tokens.font.scale[name] || 1))
    }

    function gap(name) {
        return Math.max(0, Math.round(root.spacing * (Tokens.space[name] || 1)))
    }

    function duration(name) {
        return Tokens.duration(name)
    }
}
