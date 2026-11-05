import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../kit"
import "../kit/base"
import "format.js" as Format
import "vpn.js" as Vpn

// VPN popup: the tunnel at a glance, then every imported connection with its
// connect / disconnect button and its quality (ping and level, measured by
// `vitrail.network probe`, which the settings window also runs). Sized to its
// content; the caller places it in the bar popup.
//
// The quality is read from network-state.json in `configDir`. When nothing
// measured the connections within the `probe` interval, the panel asks for a
// probe (`probeRequested`; the bar writes the request the way the settings
// window does), at most once per interval.
Item {
    id: root

    property var strings: ({})
    // The Vitrail preference folder, where network-state.json lives.
    property string configDir: ""
    // The link's latency and traffic (`vitrail.network link`).
    property var stats: ({})
    signal probeRequested()

    // { "<id>": { latency, loss } } and when the file was written (ms).
    property var quality: ({})
    property real measured: 0
    property real asked: 0

    property var connections: []
    // VPN id being connected or disconnected, until the list catches up.
    property string pending: ""
    readonly property var activeVpn: Vpn.active(root.connections)
    // How the link moves: "12 ms · ↓ 1.2 MB/s ↑ 80 kB/s", or nothing.
    readonly property string metrics: Format.summary(root.stats)

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    // Asks for a new measurement when the last one is older than the probe
    // interval; called whenever the list refreshes.
    function measure() {
        var now = Date.now()
        if (!Vpn.needsProbe(now, root.measured, root.asked, VitrailTokens.duration("probe"), root.connections.length))
            return
        root.asked = now
        root.probeRequested()
    }

    function runCommand(argv) {
        command.command = argv
        command.running = true
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
                color: VitrailTokens.solid("primary", root.activeVpn ? 0.18 : 0.06)

                Behavior on color { ColorAnimation { duration: VitrailTokens.duration("base") } }

                VitrailText {
                    anchors.centerIn: parent
                    variant: "icon"
                    text: root.activeVpn ? "shield_lock" : "shield"
                    filled: root.activeVpn !== null
                    color: root.activeVpn ? VitrailTokens.color("primary") : VitrailTokens.color("muted")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    variant: "subtitle"
                    text: root.t("network.vpn")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "content"
                    elide: Text.ElideRight
                    text: root.activeVpn
                          ? root.t("network.vpnActive") + " " + Vpn.title(root.activeVpn.name)
                          : root.t("network.vpnInactive")
                }

                VitrailText {
                    Layout.fillWidth: true
                    visible: root.metrics !== ""
                    variant: "label"
                    elide: Text.ElideRight
                    text: root.metrics
                }
            }

            // The provider of the tunnel that is up.
            Rectangle {
                visible: root.activeVpn !== null && Vpn.provider(root.activeVpn) !== ""
                implicitWidth: badge.implicitWidth + 2 * VitrailTokens.gap("sm")
                implicitHeight: badge.implicitHeight + VitrailTokens.gap("xs")
                radius: height / 2
                color: VitrailTokens.solid("primary", 0.18)

                VitrailText {
                    id: badge

                    anchors.centerIn: parent
                    variant: "label"
                    text: root.activeVpn ? Vpn.provider(root.activeVpn) : ""
                    color: VitrailTokens.color("primary")
                    opacity: 1
                }
            }
        }

        // --- connections -----------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Scroller {
                visible: root.connections.length > 0

                Repeater {
                    model: root.connections

                    delegate: Entry {
                        id: connection

                        required property var modelData

                        width: parent.width
                        icon: connection.modelData.active ? "shield_lock" : "shield"
                        active: connection.modelData.active
                        busy: root.pending === connection.modelData.id
                        title: Vpn.title(connection.modelData.name)
                        subtitle: Vpn.detail(connection.modelData)
                        quality: Vpn.level(root.quality[connection.modelData.id])
                        qualityText: Vpn.latency(root.quality[connection.modelData.id])
                        action: connection.modelData.active ? root.t("network.disconnect") : root.t("network.connect")
                        onTriggered: {
                            root.pending = connection.modelData.id
                            if (connection.modelData.active)
                                root.runCommand(["vitrail-vpn", "disconnect"])
                            else
                                root.runCommand(["vitrail-vpn", "connect", connection.modelData.id])
                        }
                    }
                }
            }

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                visible: root.connections.length === 0
                variant: "content"
                text: root.t("network.vpnEmpty")
            }
        }
    }

    // --- backends -------------------------------------------------------------
    Process {
        id: command

        running: false
        onExited: refresh.restart()
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
                root.pending = ""
                root.measure()
            }
        }
    }

    FileView {
        path: root.configDir !== "" ? root.configDir + "/network-state.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: {
            try {
                var state = JSON.parse(this.text())
                root.quality = (state.vpn && state.vpn.quality) || ({})
                root.measured = state.updated || 0
            } catch (error) {
                root.quality = ({})
            }
        }
        onLoadFailed: root.quality = ({})
    }

    Timer {
        id: refresh

        interval: 1200
        onTriggered: list.running = true
    }

    Timer {
        interval: 5000
        running: root.visible
        repeat: true
        onTriggered: list.running = true
    }
}
