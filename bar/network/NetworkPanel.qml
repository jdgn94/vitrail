import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import "../kit"
import "../kit/base"
import "format.js" as Format
import "network.js" as Network

// Network popup: a status header, then Ethernet and Wi-Fi.
// Sized to its content; the caller places it in the bar popup.
Item {
    id: root

    property var strings: ({})
    // The link's latency and traffic (`vitrail.network link`).
    property var stats: ({})
    // "internet" or "bluetooth": the connection chip and the Bluetooth chip
    // both open this popup, each on its own tab.
    property string tab: "internet"
    // What `vitrail.network bluetooth` printed, for the Bluetooth tab.
    property var bluetooth: ({})

    // The Bluetooth tab asks the shell for a fresh copy after an action.
    signal refreshRequested()

    // --- state ---------------------------------------------------------------
    readonly property var wifiDevice: root.deviceOf(DeviceType.Wifi, false)
    readonly property var wiredDevice: root.deviceOf(DeviceType.Wired, true)
    readonly property bool hasWifi: root.wifiDevice !== null
    readonly property var wifiNetwork: {
        var networks = root.wifiDevice ? root.wifiDevice.networks.values : []
        for (var i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i]
        }
        return null
    }
    // NetworkManager may not list the devices (Quickshell 0.3 skips some
    // setups), yet still reports connectivity: that alone counts as online.
    readonly property bool online: root.wiredDevice !== null || root.wifiNetwork !== null
                                   || Networking.connectivity === NetworkConnectivity.Full
    // How the link moves: "12 ms · ↓ 1.2 MB/s ↑ 80 kB/s", or nothing.
    readonly property string metrics: Format.summary(root.stats)

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // First device of a type, or the first connected one when asked.
    function deviceOf(type, connected) {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === type && (!connected || devices[i].connected))
                return devices[i]
        }
        return null
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "internet", icon: "public", label: root.t("connection.tab.internet") },
                { key: "bluetooth", icon: "bluetooth", label: root.t("connection.bluetooth") }
            ]
            current: root.tab
            onSelected: function (key) { root.tab = key }
        }

        // --- Internet --------------------------------------------------------
        ColumnLayout {
            id: internet

            Layout.fillWidth: true
            visible: root.tab === "internet"
            spacing: VitrailTokens.gap("md")

        // --- status ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            Rectangle {
                implicitWidth: VitrailTokens.size("display") + VitrailTokens.gap("sm")
                implicitHeight: implicitWidth
                radius: width / 2
                color: VitrailTokens.solid("primary", root.online ? 0.18 : 0.06)

                Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }

                VitrailText {
                    anchors.centerIn: parent
                    variant: "icon"
                    icon: root.wiredDevice ? "lan"
                          : root.wifiNetwork ? Network.wifiGlyph(root.wifiNetwork.signalStrength)
                          : root.online ? "lan" : "signal_wifi_off"
                    color: root.online ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    variant: "subtitle"
                    text: root.t("network.title")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    elide: Text.ElideRight
                    text: root.wiredDevice ? root.t("network.ethernet") + " · " + root.wiredDevice.name
                          : root.wifiNetwork ? root.t("network.wifi") + " · " + root.wifiNetwork.name
                          : root.online ? root.t("network.connected") : root.t("network.offline")
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: root.metrics !== ""
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.metrics
                }
            }
        }

        // --- ethernet + wifi -------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: Networking.devices

                delegate: Entry {
                    id: wired

                    required property var modelData

                    visible: wired.modelData.type === DeviceType.Wired
                    icon: "lan"
                    active: wired.modelData.connected
                    title: wired.modelData.name
                    subtitle: !wired.modelData.hasLink ? root.t("network.linkDown")
                              : (wired.modelData.connected ? root.t("network.connected") : root.t("network.offline"))
                                + (wired.modelData.linkSpeed > 0 ? " · " + wired.modelData.linkSpeed + " Mb/s" : "")
                    action: wired.modelData.connected ? root.t("network.disconnect") : root.t("network.connect")
                    onTriggered: {
                        if (wired.modelData.connected)
                            wired.modelData.disconnect()
                        else if (wired.modelData.network)
                            wired.modelData.network.connect()
                    }
                }
            }

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                visible: Networking.devices.values.length === 0 && !root.online
                variant: "content"
                text: root.t("network.noDevices")
            }

            // No Wi-Fi hardware: no switch, just the reason.
            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                Layout.topMargin: VitrailTokens.gap("xs")
                visible: !root.hasWifi
                variant: "content"
                text: root.t("network.wifiMissing")
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: VitrailTokens.gap("xs")
                Layout.leftMargin: VitrailTokens.gap("sm")
                Layout.rightMargin: VitrailTokens.gap("sm")
                visible: root.hasWifi

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    text: root.t("network.wifiEnabled")
                }

                VitrailSwitch {
                    checked: Networking.wifiEnabled
                    onToggled: function (value) { Networking.wifiEnabled = value }
                }
            }

            Scroller {
                visible: root.hasWifi && Networking.wifiEnabled

                Repeater {
                    model: root.wifiDevice ? root.wifiDevice.networks : []

                    delegate: Entry {
                        id: wifi

                        required property var modelData

                        width: parent.width
                        icon: Network.wifiGlyph(wifi.modelData.signalStrength)
                        active: wifi.modelData.connected
                        busy: wifi.modelData.stateChanging
                        title: wifi.modelData.name
                        subtitle: Math.round((wifi.modelData.signalStrength || 0) * 100) + "%"
                                  + (wifi.modelData.connected ? " · " + root.t("network.connected") : "")
                        action: wifi.modelData.connected ? root.t("network.disconnect") : root.t("network.connect")
                        onTriggered: {
                            if (wifi.modelData.connected)
                                wifi.modelData.disconnect()
                            else
                                wifi.modelData.connect()
                        }
                    }
                }
            }
        }
        }

        // --- Bluetooth -------------------------------------------------------
        BluetoothPanel {
            Layout.fillWidth: true
            visible: root.tab === "bluetooth"
            strings: root.strings
            bluetooth: root.bluetooth
            onRefreshRequested: root.refreshRequested()
        }
    }
}
