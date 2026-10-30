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

    // User-tunable values, mirrored from settings.ini.
    property real spacing: Tokens.ranges.spacing.value
    property real radius: Tokens.ranges.radius.value
    property real blur: Tokens.ranges.blur.value
    property real opacity: Tokens.ranges.opacity.value
    property real fontBase: Tokens.font.base
    property real frame: Tokens.ranges.frame.value
    property real bar: Tokens.ranges.bar.value
    property real panel: Tokens.ranges.panel.value

    readonly property var ranges: Tokens.ranges
    readonly property var font: Tokens.font
    readonly property var motion: Tokens.motion
    readonly property var slider: Tokens.slider
    readonly property var field: Tokens.field
    readonly property string fontFamily: Tokens.font.family
    readonly property string iconFamily: Tokens.font.icons

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
