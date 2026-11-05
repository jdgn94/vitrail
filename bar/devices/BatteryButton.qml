import QtQuick
import Quickshell.Services.UPower
import "../kit/base"
import "devices.js" as Devices

// The battery chip at the end of the bar: the charge and a glyph that follows
// it, a tooltip with the state and the time left, and a click on the power
// profile popup. Only a machine with a battery shows it; the charge comes from
// Quickshell's UPower service, so there is no process behind it.
VitrailButton {
    id: root

    property var strings: ({})
    property bool opened: false
    // The preference: the user can keep the chip out of the bar.
    property bool show: true

    readonly property var device: UPower.displayDevice
    readonly property bool shown: root.show && Devices.batteryShown(root.device)
    readonly property string percent: Devices.batteryPercent(root.device ? root.device.percentage : null)
    readonly property string chargeState: Devices.batteryState(root.device ? root.device.state : -1)
    readonly property var remaining: Devices.timeParts(Devices.batterySeconds(root.device))
    readonly property string time: Devices.durationText(root.remaining, root.strings)

    // What the pointer reads: the charge, then what it is doing and for how
    // long (a full battery has no time to give).
    property string tooltip: root.t("battery.label") + (root.percent === "" ? "" : " · " + root.percent)
    property string tooltipDetail: {
        var parts = [root.t("battery." + root.chargeState)]
        if (root.time !== "" && (root.chargeState === "charging" || root.chargeState === "discharging")) {
            var until = root.chargeState === "charging" ? "battery.untilFull" : "battery.remaining"
            parts.push(root.t(until).replace("%1", root.time))
        }
        return parts.join(" · ")
    }

    visible: root.shown
    variant: root.opened ? "tonal" : "plain"
    tone: root.chargeState === "empty" || (Devices.batteryShown(root.device) && root.device.percentage <= 15
                                           && !Devices.batteryCharging(root.device)) ? "error"
          : Devices.batteryCharging(root.device) ? "primary" : "secondary"
    size: "sm"
    icon: Devices.batteryGlyph(root.device)
    text: root.percent

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }
}
