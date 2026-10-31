import QtQuick
import Quickshell.Io
import "../kit"
import "../kit/base"
import "vpn.js" as Vpn

// The VPN button: a closed shield when a tunnel is up, an open one when not.
// The tunnels come from `hypraether-vpn list --json`.
Item {
    id: root

    property bool opened: false
    property var strings: ({})

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    property var connections: []
    readonly property var activeVpn: Vpn.active(root.connections)

    // What the pointer reads: the provider and its server, or that none is up.
    property string tooltip: root.activeVpn ? Vpn.provider(root.activeVpn) || Vpn.title(root.activeVpn.name)
                                            : root.t("tooltip.noVpn")
    property string tooltipDetail: root.activeVpn ? Vpn.service(root.activeVpn) : ""

    implicitWidth: glyph.implicitWidth + VitrailTokens.gap("sm")
    implicitHeight: glyph.implicitHeight + VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: VitrailTokens.radius / 2
        color: VitrailTokens.color("primary")
        opacity: root.opened ? 0.16 : 0
        Behavior on opacity { NumberAnimation { duration: VitrailTokens.duration("fast") } }
    }

    VitrailText {
        id: glyph

        anchors.centerIn: parent
        variant: "icon"
        text: root.activeVpn ? "shield_lock" : "shield"
        filled: root.activeVpn !== null
        color: root.activeVpn ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
        opacity: root.activeVpn ? 1 : 0.45
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
        id: list

        command: ["hypraether-vpn", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.connections = JSON.parse(this.text)
                } catch (error) {
                    root.connections = []
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: list.running = true
    }
}
