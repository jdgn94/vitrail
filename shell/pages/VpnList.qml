import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/network/vpn.js" as Vpn

// The VPN tab's first view: hypraether's connections, each with its settings
// button at the left, its ping and quality (every connection, as the last probe
// measured it) and Connect / Disconnect; the buttons to add a connection and
// to the global settings close the section.
Section {
    id: root

    // The Connection page: its state, `ask` and navigation.
    property var page

    function t(key) {
        return root.page.t(key)
    }

    icon: "vpn_key"
    title: root.t("connection.vpn.connections")
    foreground: root.page.palette.foreground
    accent: root.page.palette.primary

    VitrailText {
        Layout.fillWidth: true
        visible: !root.page.vpn.available
        variant: "content"
        text: root.t("connection.vpn.missing")
    }

    VitrailText {
        Layout.fillWidth: true
        visible: root.page.vpn.available === true && root.page.tunnels.length === 0
        variant: "content"
        text: root.t("network.vpnEmpty")
    }

    Repeater {
        model: root.page.tunnels

        delegate: RowLayout {
            id: tunnel

            required property var modelData

            readonly property bool active: tunnel.modelData.active
            readonly property string request: (tunnel.active ? "vpn-down:" : "vpn-up:") + tunnel.modelData.id
            readonly property var measure: root.page.quality[tunnel.modelData.id]
            readonly property string level: Vpn.level(tunnel.measure)

            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: "tune"
                onClicked: root.page.openConnection(tunnel.modelData.id)
            }

            VitrailSettingRow {
                icon: tunnel.active ? "shield_lock" : "shield"
                label: Vpn.title(tunnel.modelData.name)
                description: root.page.parts([
                    tunnel.active ? root.t("network.connected") : root.t("network.offline"),
                    Vpn.provider(tunnel.modelData),
                    tunnel.modelData.region,
                    tunnel.modelData.credential !== "" ? tunnel.modelData.credential : root.t("connection.vpn.noCredential")
                ])
                foreground: root.page.palette.foreground
                muted: root.page.palette.muted

                VitrailQuality {
                    level: tunnel.level
                    text: tunnel.level === "unknown" ? Vpn.latency(tunnel.measure)
                                                     : Vpn.latency(tunnel.measure) + " · " + root.t("connection.vpn.quality." + tunnel.level)
                }

                VitrailButton {
                    variant: "tonal"
                    tone: tunnel.active ? "secondary" : "primary"
                    text: tunnel.active ? root.t("network.disconnect") : root.t("network.connect")
                    busy: root.page.busy === tunnel.request
                    enabled: root.page.idle && (tunnel.active || tunnel.modelData.credential !== "")
                    onClicked: root.page.ask(tunnel.request)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        VitrailButton {
            variant: "tonal"
            icon: "add"
            text: root.t("connection.vpn.add")
            onClicked: root.page.openImport()
        }

        VitrailButton {
            variant: "tonal"
            icon: "settings"
            text: root.t("connection.vpn.global")
            onClicked: root.page.openGlobal()
        }
    }
}
