import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../kit"
import "../kit/base"
import "vpn.js" as Vpn

// VPN popup: the tunnel at a glance, then every imported connection with its
// connect / disconnect button. Sized to its content; the caller places it in
// the bar popup.
Item {
    id: root

    property var strings: ({})

    property var connections: []
    // The Connection page's VPN document: which connections the active user
    // may raise.
    property string settings: ""
    readonly property var offered: Vpn.available(root.connections, root.settings)
    // VPN id being connected or disconnected, until the list catches up.
    property string pending: ""
    readonly property var activeVpn: Vpn.active(root.connections)

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
                visible: root.offered.length > 0

                Repeater {
                    model: root.offered

                    delegate: Entry {
                        id: connection

                        required property var modelData

                        width: parent.width
                        icon: connection.modelData.active ? "shield_lock" : "shield"
                        active: connection.modelData.active
                        busy: root.pending === connection.modelData.id
                        title: Vpn.title(connection.modelData.name)
                        subtitle: Vpn.detail(connection.modelData)
                        action: connection.modelData.active ? root.t("network.disconnect") : root.t("network.connect")
                        onTriggered: {
                            root.pending = connection.modelData.id
                            if (connection.modelData.active)
                                root.runCommand(["hypraether-vpn", "disconnect"])
                            else
                                root.runCommand(["hypraether-vpn", "connect", connection.modelData.id])
                        }
                    }
                }
            }

            VitrailText {
                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                visible: root.offered.length === 0
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

        command: ["hypraether-vpn", "list", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.connections = JSON.parse(this.text)
                } catch (error) {
                    root.connections = []
                }
                root.pending = ""
            }
        }
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
