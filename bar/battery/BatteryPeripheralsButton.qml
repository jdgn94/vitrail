import QtQuick
import ".."
import "battery.js" as Battery

// The peripherals battery bar element: the lowest battery among the watched
// mouse, keyboard, headset and gamepad, from vitrail.battery's snapshot
// (BarSnapshot). "Only while active" is the element's default mode
// (bar/elements.js): without a watched device that reports a percentage there
// is no number to show, so the button leaves the bar instead of holding an
// empty slot; "always" keeps the glyph in place for a steady layout. The
// `peripheralsHide` preference leaves whole kinds out, so the lowest is chosen
// among the devices the user still watches.
BarElementBase {
    id: root

    // The element's data: vitrail.battery's snapshot.
    property var snapshot: ({})
    // The `peripheralsHide` preference (kinds, one JSON array).
    property string hide: ""
    // The `peripheralsLow` warning threshold, in percent.
    property int low: 20

    readonly property bool ready: Battery.ready(root.snapshot)
    readonly property var devices: Battery.watchedDevices(root.snapshot, root.hide)
    readonly property var lowest: Battery.lowest(root.devices)

    icon: Battery.glyph(root.lowest)
    text: root.lowest ? Battery.percentText(root.lowest) : ""
    tone: Battery.tone(root.lowest, root.low)
    showMode: "active"
    active: root.lowest !== null
    tooltip: !root.ready ? root.t("bar.widget.peripherals")
             : root.lowest === null ? root.t("bar.peripherals.empty")
             : root.t("bar.peripherals.level")
                   .replace("%1", root.lowest.name)
                   .replace("%2", Battery.percentage(root.lowest))
    tooltipDetail: !root.ready ? root.t("bar.peripherals.unreadable")
                   : root.lowest === null ? root.t("bar.peripherals.empty")
                   : root.devices.length > 1 ? Battery.others(root.devices, root.lowest)
                                             : Battery.stateText(root.lowest, root.strings)
}
