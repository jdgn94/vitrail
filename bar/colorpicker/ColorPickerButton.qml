import QtQuick
import ".."

// The colour picker bar element: an eyedropper. A click picks a colour from the
// screen with the same tool the palette uses; the popup opened with a right
// click lists the recent colours and opens the palette.
BarElementBase {
    id: root

    // The recent colours, newest first (`colorpickerColors`, up to 24).
    property var colors: []

    readonly property int count: root.colors.length
    readonly property string newest: root.count > 0 ? String(root.colors[0]) : ""
    readonly property string oldest: root.count > 0 ? String(root.colors[root.count - 1]) : ""

    icon: "colorize"
    // The screen is always there to pick from.
    active: true
    tooltip: root.count === 0 ? root.t("bar.colorpicker.none")
             : root.count === 1 ? root.t("bar.colorpicker.tooltip.one").replace("%1", root.newest)
                                : root.t("bar.colorpicker.tooltip")
                                    .replace("%1", root.count).replace("%2", root.newest)
    tooltipDetail: root.count === 0 ? root.t("bar.colorpicker.pickHint")
                                    : root.t("bar.colorpicker.oldest").replace("%1", root.oldest)
}
