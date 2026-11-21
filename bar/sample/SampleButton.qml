import QtQuick
import ".."
import "../kit"

// Sample bar element: exercises BarElementBase and the Python snapshot
// pattern. Hidden by default; enable it in bar/layouts.js or the editor.
BarElementBase {
    id: root

    property var data: ({})
    property var strings: ({})

    tooltip: root.data.message ? String(root.data.message) : root.t("bar.widget.sample.tooltip")
    tooltipDetail: root.t("bar.widget.sample.tooltipDetail")
    showMode: "always"
    icon: "widgets"

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }
}
