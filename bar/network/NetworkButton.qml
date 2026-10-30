import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../kit"
import "../kit/base"

// One button for the connection and the VPN.
//
// The icon is the active connection: Ethernet if it is up, Wi-Fi if that is
// the link in use, and the usual one dimmed when nothing is connected.
Item {
    id: root

    property bool opened: false
    property bool vertical: false

    signal clicked()

    readonly property alias hovered: hover.hovered

    readonly property bool ethernetOn: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wired && devices[i].connected)
                return true
        }
        return false
    }
    readonly property bool wifiOn: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi && devices[i].connected)
                return true
        }
        return false
    }
    readonly property bool hasWifi: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return true
        }
        return false
    }
    property bool vpnOn: false

    // Ethernet wins when both are up: it is the link the system prefers.
    readonly property string glyph: root.wifiOn && !root.ethernetOn ? "wifi" : "lan"
    // Connectivity covers setups whose devices NetworkManager does not list.
    readonly property bool connected: root.ethernetOn || root.wifiOn
                                      || Networking.connectivity === NetworkConnectivity.Full

    implicitWidth: icons.implicitWidth + VitrailTokens.gap("sm")
    implicitHeight: icons.implicitHeight + VitrailTokens.gap("xs")

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: VitrailTokens.color("primary")
        opacity: root.opened ? 0.16 : 0
        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    GridLayout {
        id: icons

        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: VitrailTokens.gap("xs")
        columnSpacing: VitrailTokens.gap("xs")

        VitrailText {
            variant: "icon"
            text: root.glyph
            color: root.connected ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
            opacity: root.connected ? 1 : 0.45
        }

        VitrailText {
            variant: "icon"
            text: "vpn_lock"
            color: root.vpnOn ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
            opacity: root.vpnOn ? 1 : 0.45
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Process {
        id: vpnList

        command: ["hypraether-vpn", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var connections = JSON.parse(this.text)
                    for (var i = 0; i < connections.length; i++) {
                        if (connections[i].active) {
                            root.vpnOn = true
                            return
                        }
                    }
                    root.vpnOn = false
                } catch (error) {
                    root.vpnOn = false
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: vpnList.running = true
    }
}
