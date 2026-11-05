import QtQuick
import "../kit"
import "../kit/base"
import "devices.js" as Devices

// The Bluetooth chip in the connection group: the adapter on or off, a badge
// with how many devices are connected, and a tooltip with the peripheral and
// its battery when BlueZ exposes it. Only a machine with an adapter shows it.
VitrailButton {
    id: root

    property var strings: ({})
    property bool opened: false
    // The preference: the user can keep the chip out of the bar.
    property bool show: true
    // What `vitrail.network bluetooth` printed: available, powered, devices.
    property var bluetooth: ({})

    readonly property var info: Devices.bluetoothInfo(root.bluetooth)

    // What the pointer reads: the adapter, how many are connected, and the
    // first peripheral with its battery.
    property string tooltip: root.info.powered && root.info.connected > 0
                             ? root.t("bluetooth.label") + " · "
                               + root.t("bluetooth.count").replace("%1", root.info.connected)
                             : root.t("bluetooth.label")
    property string tooltipDetail: {
        if (!root.info.powered)
            return root.t("bluetooth.off")
        if (!root.info.device)
            return root.t("bluetooth.none")
        var device = root.info.device
        if (device.battery === null || device.battery === undefined)
            return device.name
        return device.name + " · " + root.t("connection.battery").replace("%1", device.battery)
    }

    visible: root.show && root.info.shown
    variant: root.opened ? "tonal" : "plain"
    tone: root.info.powered && root.info.connected > 0 ? "primary" : "secondary"
    size: "sm"
    icon: root.info.powered ? "bluetooth" : "bluetooth_disabled"

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailBadge {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: VitrailTokens.gap("xs")
        tone: "primary"
        text: root.info.badge
    }
}
