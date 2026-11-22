import QtQuick
import ".."
import "brightness.js" as Brightness

// The brightness bar element: a sun glyph that follows the primary monitor's
// level, the wheel moves that monitor by the configured step, and a click
// opens the popup. The levels are the OSD's (`brightness.js`), read from the
// same `vitrail brightness list`, so the key and the wheel share one
// arithmetic. The step is applied per notch; the OSD's writer debounces, so a
// fast spin coalesces into one command per display.
BarElementBase {
    id: root

    // The element's data, the shape `vitrail brightness list` prints.
    property var snapshot: ({})
    // The primary output's Hyprland name; "" falls back to the first readable
    // monitor.
    property string primary: ""
    // The percent one wheel notch moves (`brightnessStep`).
    property real step: 5

    signal brightnessRequested(string name, real percent)

    readonly property var target: Brightness.primary(root.snapshot, root.primary)
    readonly property bool ready: Brightness.ready(root.snapshot)

    icon: Brightness.icon(root.target)
    tone: "secondary"
    text: ""
    // Brightness is always meaningful: there is nothing to hide while it has
    // a value, and the popup explains the reason when it does not.
    active: true
    tooltip: root.target ? String(root.target.name) : root.t("bar.widget.brightness")
    tooltipDetail: root.target ? Math.round(root.target.percent) + "%"
                               : root.t(Brightness.reasonFor(root.snapshot, ""))

    onWheeled: function (delta) {
        var change = Brightness.wheelTarget(root.snapshot, root.primary, delta, root.step)
        if (change !== null)
            root.brightnessRequested(change.name, change.percent)
    }
}
