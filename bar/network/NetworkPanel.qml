import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../kit"
import "../kit/base"

// Network popup: a status header, then Ethernet + Wi-Fi and VPN as tabs.
// Sized to its content; the caller places it in the bar popup.
Item {
    id: root

    property var strings: ({})
    property string tab: "network"

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
    property var vpnConnections: []
    // VPN id being connected or disconnected, until the list catches up.
    property string vpnPending: ""
    readonly property var activeVpn: {
        for (var i = 0; i < root.vpnConnections.length; i++) {
            if (root.vpnConnections[i].active)
                return root.vpnConnections[i]
        }
        return null
    }
    // NetworkManager may not list the devices (Quickshell 0.3 skips some
    // setups), yet still reports connectivity: that alone counts as online.
    readonly property bool online: root.wiredDevice !== null || root.wifiNetwork !== null
                                   || Networking.connectivity === NetworkConnectivity.Full

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function runCommand(argv) {
        command.command = argv
        command.running = true
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

    // Signal bars, from empty to full.
    function wifiGlyph(strength) {
        var glyphs = ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"]
        return glyphs[Math.max(0, Math.min(4, Math.round((strength || 0) * 4)))]
    }

    // "us-free-12.protonvpn.udp.ovpn" reads as "us-free-12" over
    // "protonvpn · udp".
    function vpnTitle(name) {
        return name.replace(/\.(ovpn|conf)$/, "").split(".")[0]
    }

    function vpnDetail(connection) {
        var parts = connection.name.replace(/\.(ovpn|conf)$/, "").split(".").slice(1)
        if (connection.region)
            parts.push(connection.region)
        return parts.join(" · ")
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        // --- status ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            Rectangle {
                implicitWidth: VitrailTokens.size("display") + VitrailTokens.gap("sm")
                implicitHeight: implicitWidth
                radius: width / 2
                color: Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                               VitrailTokens.color("primary").b, root.online ? 0.18 : 0.06)

                Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }

                VitrailText {
                    anchors.centerIn: parent
                    variant: "icon"
                    text: root.wiredDevice ? "lan"
                          : root.wifiNetwork ? root.wifiGlyph(root.wifiNetwork.signalStrength)
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
            }

            // The tunnel at a glance, whichever tab is open.
            Rectangle {
                visible: root.activeVpn !== null
                implicitWidth: vpnBadge.implicitWidth + 2 * VitrailTokens.gap("sm")
                implicitHeight: vpnBadge.implicitHeight + VitrailTokens.gap("xs")
                radius: height / 2
                color: Qt.rgba(VitrailTokens.color("primary").r, VitrailTokens.color("primary").g,
                               VitrailTokens.color("primary").b, 0.18)

                Row {
                    id: vpnBadge

                    anchors.centerIn: parent
                    spacing: VitrailTokens.gap("xs")

                    VitrailText {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "icon"
                        font.pixelSize: VitrailTokens.size("label")
                        text: "shield_lock"
                        filled: true
                        color: VitrailTokens.color("primary")
                    }

                    VitrailText {
                        anchors.verticalCenter: parent.verticalCenter
                        variant: "label"
                        text: root.t("network.vpn")
                        color: VitrailTokens.color("primary")
                        opacity: 1
                    }
                }
            }
        }

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "network", label: root.t("network.network") },
                { key: "vpn", label: root.t("network.vpn") }
            ]
            current: root.tab
            onSelected: function (key) { root.tab = key }
        }

        // --- network (ethernet + wifi) ---------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.tab === "network"
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
                        icon: root.wifiGlyph(wifi.modelData.signalStrength)
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

        // --- vpn -------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.tab === "vpn"
            spacing: VitrailTokens.gap("xs")

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                variant: "content"
                elide: Text.ElideRight
                text: root.activeVpn
                      ? root.t("network.vpnActive") + " " + root.vpnTitle(root.activeVpn.name)
                      : root.t("network.vpnInactive")
            }

            Scroller {
                visible: root.vpnConnections.length > 0

                Repeater {
                    model: root.vpnConnections

                    delegate: Entry {
                        id: vpn

                        required property var modelData

                        width: parent.width
                        icon: vpn.modelData.active ? "shield_lock" : "shield"
                        active: vpn.modelData.active
                        busy: root.vpnPending === vpn.modelData.id
                        title: root.vpnTitle(vpn.modelData.name)
                        subtitle: root.vpnDetail(vpn.modelData)
                        action: vpn.modelData.active ? root.t("network.disconnect") : root.t("network.connect")
                        onTriggered: {
                            root.vpnPending = vpn.modelData.id
                            if (vpn.modelData.active)
                                root.runCommand(["hypraether-vpn", "disconnect"])
                            else
                                root.runCommand(["hypraether-vpn", "connect", vpn.modelData.id])
                        }
                    }
                }
            }

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                visible: root.vpnConnections.length === 0
                variant: "content"
                text: root.t("network.vpnEmpty")
            }
        }
    }

    // One connection: icon, name and detail, and its connect button. The
    // active one is tinted; the others light up under the pointer.
    component Entry: Item {
        id: entry

        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property string action: ""
        property bool active: false
        property bool busy: false

        signal triggered()

        Layout.fillWidth: true
        implicitHeight: line.implicitHeight + 2 * VitrailTokens.gap("xs")

        Rectangle {
            anchors.fill: parent
            radius: VitrailTokens.radius / 2
            color: entry.active ? VitrailTokens.color("primary") : VitrailTokens.color("foreground")
            opacity: entry.active ? 0.14 : (hover.hovered ? 0.06 : 0)

            Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
        }

        HoverHandler {
            id: hover
        }

        RowLayout {
            id: line

            anchors.verticalCenter: parent.verticalCenter
            x: VitrailTokens.gap("sm")
            width: parent.width - 2 * VitrailTokens.gap("sm")
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                // Glyphs differ in width; a fixed slot keeps the names aligned.
                Layout.preferredWidth: VitrailTokens.size("display")
                horizontalAlignment: Text.AlignHCenter
                variant: "icon"
                text: entry.icon
                color: entry.active ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    font.weight: entry.active ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    text: entry.title
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: entry.subtitle !== ""
                    variant: "label"
                    elide: Text.ElideRight
                    text: entry.subtitle
                }
            }

            VitrailButton {
                visible: entry.action !== ""
                enabled: !entry.busy
                variant: entry.active ? "outlined" : "tonal"
                tone: entry.active ? "secondary" : "primary"
                text: entry.busy ? root.t("network.connecting") : entry.action
                onClicked: entry.triggered()
            }
        }
    }

    // A list that scrolls past a handful of rows, so the popup stays small.
    component Scroller: Flickable {
        default property alias rows: column.data

        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(column.implicitHeight, VitrailTokens.size("display") * 8)
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xs")
        }
    }

    // --- backends -------------------------------------------------------------
    Process {
        id: command

        running: false
        onExited: vpnRefresh.restart()
    }

    Process {
        id: vpnList

        command: ["hypraether-vpn", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vpnConnections = JSON.parse(this.text)
                } catch (error) {
                    root.vpnConnections = []
                }
                root.vpnPending = ""
            }
        }
    }

    Timer {
        id: vpnRefresh
        interval: 1200
        onTriggered: vpnList.running = true
    }

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        onTriggered: vpnList.running = true
    }
}
