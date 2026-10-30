import QtQuick

// Wallpaper palette, injected by bin/vitrail-settings as one JSON argument.
// Falls back to a neutral palette when `vitrail colors` has not run yet.
QtObject {
    id: root

    property bool dark: true
    property var data: ({})

    readonly property color surface: data.surface || (dark ? "#111318" : "#f5f7fa")
    readonly property color surfaceHigh: data.surface_container_high || (dark ? "#282a2f" : "#e6e9ee")
    readonly property color foreground: data.on_surface || (dark ? "#e2e2e9" : "#1b1f24")
    readonly property color muted: data.on_surface_variant || (dark ? "#c4c6d0" : "#4a4f57")
    readonly property color primary: data.primary || "#a8c7fa"
    readonly property color accentForeground: data.on_primary || "#002f65"
    // Info leans on the tertiary tone so it still harmonises with the wallpaper.
    readonly property color info: data.tertiary || (dark ? "#a6c8ff" : "#2d5fa6")
    readonly property color infoForeground: data.on_tertiary || (dark ? "#00315f" : "#ffffff")
    readonly property color error: data.error || (dark ? "#ffb4ab" : "#ba1a1a")
    readonly property color errorForeground: data.on_error || (dark ? "#690005" : "#ffffff")
    readonly property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
}
