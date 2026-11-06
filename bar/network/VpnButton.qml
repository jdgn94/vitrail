import QtQuick
import Quickshell.Io
import "../kit"
import "../kit/base"
import "format.js" as Format
import "vpn.js" as Vpn

// The VPN button: a shield with a lock, the accent colour while a tunnel is
// up and the muted one when not. The tunnels come from `vitrail-vpn list
// --json`.
Item {
    id: root

    property bool opened: false
    property var strings: ({})
    // The link's latency and traffic (`vitrail.network link`).
    property var stats: ({})

    signal clicked()

    readonly property alias hovered: hover.hovered
    readonly property alias pressed: area.pressed

    property var connections: []
    readonly property var activeVpn: Vpn.active(root.connections)

    // What the pointer reads: the provider and its server, or that none is up,
    // then how the link moves.
    readonly property string metrics: Format.summary(root.stats)
    property string tooltip: root.activeVpn ? Vpn.provider(root.activeVpn) || Vpn.title(root.activeVpn.name)
                                            : root.t("tooltip.noVpn")
    property string tooltipDetail: [root.activeVpn ? Vpn.service(root.activeVpn) : "", root.metrics].filter(
        function (part) {
            return part !== ""
        }).join(" · ")

    implicitWidth: glyph.implicitWidth + VitrailTokens.gap("sm")
    // Square, so the round background fits the chip's pill.
    implicitHeight: implicitWidth

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        visible: root.opened
        color: VitrailTokens.solid("primary", 0.16)
    }

    VitrailText {
        id: glyph

        anchors.centerIn: parent
        variant: "icon"
        icon: "shield_lock"
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

        command: ["vitrail-vpn", "list", "--json"]
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
