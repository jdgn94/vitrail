import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../launcher"
import "../launcher/commands.js" as Commands
import "../devices/devices.js" as Devices
import "Entry.qml"

// The Bluetooth tab of the connection popup: the adapter's switch, a scan, and
// the paired and nearby peripherals. The state is `vitrail.network bluetooth`,
// the same read the settings window's Connection page uses; every action asks
// the shell for a fresh copy (see bar/shell.qml).
Item {
    id: root

    property var strings: ({})
    property var bluetooth: ({})

    signal refreshRequested()

    readonly property var info: Devices.bluetoothInfo(root.bluetooth)

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function subtitle(device) {
        var parts = [device.connected ? root.t("network.connected") : root.t("network.offline")]
        if (device.battery !== null && device.battery !== undefined)
            parts.push(root.t("connection.battery").replace("%1", device.battery))
        return parts.join(" · ")
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        VitrailText {
            Layout.fillWidth: true
            visible: !root.info.shown
            variant: "content"
            text: root.t("connection.bluetooth.missing")
        }

        VitrailSettingRow {
            visible: root.info.shown
            icon: root.info.powered ? "bluetooth" : "bluetooth_disabled"
            label: root.t("connection.bluetooth.enabled")
            description: root.info.powered ? "" : root.t("bluetooth.off")
            foreground: VitrailTokens.color("foreground")
            muted: VitrailTokens.color("muted")

            VitrailSwitch {
                checked: root.info.powered
                enabled: !actionRun.busy
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                onToggled: function (value) { actionRun.run(Commands.bluetoothSet(value), "power") }
            }
        }

        VitrailButton {
            Layout.fillWidth: true
            visible: root.info.shown && root.info.powered
            variant: "tonal"
            tone: "secondary"
            icon: "bluetooth_searching"
            text: root.t("connection.bluetooth.scan")
            busy: actionRun.busy && actionRun.tag === "scan"
            enabled: !actionRun.busy
            onClicked: actionRun.run(Commands.bluetoothScan(), "scan")
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.info.shown && root.info.powered
            variant: "subtitle"
            text: root.t("connection.bluetooth.paired")
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.info.shown && root.info.powered && root.info.paired.length === 0
            variant: "content"
            text: root.t("connection.bluetooth.none")
        }

        Repeater {
            model: root.info.powered ? root.info.paired : []

            delegate: Entry {
                required property var modelData

                icon: modelData.connected ? "bluetooth_connected" : "bluetooth"
                active: modelData.connected
                busy: actionRun.busy
                title: modelData.name
                subtitle: root.subtitle(modelData)
                action: modelData.connected ? root.t("network.disconnect") : root.t("network.connect")
                onTriggered: actionRun.run(modelData.connected
                                        ? Commands.bluetoothDisconnect(modelData.mac)
                                        : Commands.bluetoothConnect(modelData.mac),
                                        modelData.mac)
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.info.shown && root.info.powered && root.info.nearby.length > 0
            variant: "subtitle"
            text: root.t("connection.bluetooth.nearby")
        }

        Repeater {
            model: root.info.powered ? root.info.nearby : []

            delegate: Entry {
                required property var modelData

                icon: "bluetooth"
                active: false
                busy: actionRun.busy
                title: modelData.name
                subtitle: root.subtitle(modelData)
                action: root.t("network.connect")
                onTriggered: actionRun.run(Commands.bluetoothConnect(modelData.mac), modelData.mac)
            }
        }
    }

    // One action at a time: the popup's state is read again when it ends.
    AsyncRun {
        id: actionRun

        onFinished: root.refreshRequested()
    }
}
