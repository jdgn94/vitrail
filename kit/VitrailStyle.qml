pragma Singleton
import QtQuick

// Global defaults + resolution. A component that omits `variant` inherits the
// entry for its family, so one change restyles the whole application.
QtObject {
    readonly property var defaults: ({
        text: "body",
        button: "flat",
        field: "outline",
        surface: "glass",
        frame: "full",
        bar: "docked",
        panel: "full",
        wallpaper: "frame",
        launcher: "popout",
        visualiser: "bars"
    })

    function resolve(kind, name) {
        var table = VitrailVariants[kind]
        if (!table)
            return ({})
        var key = name || defaults[kind]
        return table[key] || table[defaults[kind]] || ({})
    }

    function setDefault(kind, name) {
        if (!VitrailVariants[kind] || !VitrailVariants[kind][name])
            return
        var next = {}
        for (var k in defaults)
            next[k] = defaults[k]
        next[kind] = name
        defaults = next
    }
}
