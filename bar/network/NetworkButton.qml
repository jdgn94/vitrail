import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../kit"
import "../kit/base"
import "network.js" as Network

// The connection button: Ethernet when it is up, the Wi-Fi signal when that
// is the link in use, and a crossed-out Wi-Fi when nothing is connected. The
// VPN has its own button.
Item {
    id: root

    property bool opened: false
    property var strings: ({})

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    readonly property var wiredDevice: root.deviceOf(DeviceType.Wired)
    readonly property var wifiDevice: root.deviceOf(DeviceType.Wifi)
    readonly property var wifiNetwork: {
        var networks = root.wifiDevice ? root.wifiDevice.networks.values : []
        for (var i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i]
        }
        return null
    }
    // Ethernet wins when both are up: it is the link the system prefers.
    readonly property var linkDevice: root.wiredDevice || root.wifiDevice
    // Connectivity covers setups whose devices NetworkManager does not list.
    readonly property bool connected: root.linkDevice !== null
                                      || Networking.connectivity === NetworkConnectivity.Full
    readonly property string glyph: root.wiredDevice ? "lan"
                                    : root.wifiDevice ? Network.wifiGlyph(root.wifiNetwork ? root.wifiNetwork.signalStrength : 0)
                                    : root.connected ? "lan" : "signal_wifi_off"
    // IPv4 of the interface in use, from `ip`.
    property string address: ""

    // What the pointer reads: the connection and its address.
    property string tooltip: !root.connected ? root.t("network.offline")
                             : root.wiredDevice ? root.wiredDevice.name + " · " + root.t("tooltip.wired")
                             : root.wifiDevice && root.wifiNetwork ? root.wifiNetwork.name
                             : root.t("network.connected")
    property string tooltipDetail: root.connected ? root.address : ""

    implicitWidth: icon.implicitWidth + VitrailTokens.gap("sm")
    implicitHeight: icon.implicitHeight + VitrailTokens.gap("xs")

    // The address follows the interface in use, and changes with the lease.
    onLinkDeviceChanged: {
        root.address = ""
        Qt.callLater(root.refresh)
    }

    Component.onCompleted: Qt.callLater(root.refresh)

    // After the bindings settle, so the command names the new interface.
    function refresh() {
        addressProcess.running = root.linkDevice !== null
    }

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // The first connected device of a type.
    function deviceOf(type) {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === type && devices[i].connected)
                return devices[i]
        }
        return null
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: VitrailTokens.color("primary")
        opacity: root.opened ? 0.16 : 0
        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    VitrailText {
        id: icon

        anchors.centerIn: parent
        variant: "icon"
        text: root.glyph
        color: root.connected ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
        opacity: root.connected ? 1 : 0.45
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Process {
        id: addressProcess

        command: ["ip", "-j", "-4", "addr", "show", "dev", root.linkDevice ? root.linkDevice.name : ""]
        stdout: StdioCollector {
            onStreamFinished: root.address = Network.ipv4(this.text)
        }
    }

    Timer {
        interval: 30000
        running: root.linkDevice !== null
        repeat: true
        onTriggered: root.refresh()
    }
}
