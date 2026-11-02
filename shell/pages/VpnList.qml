import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/network/vpn.js" as Vpn
import "../vpnview.js" as View

// The VPN tab's first view: hypraether's connections, each with its settings
// button at the left, the ping of the one that is up and Connect / Disconnect;
// the button to the global settings closes the section.
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

                VitrailText {
                    visible: tunnel.active
                    variant: "content"
                    text: View.pingLabel(root.page.quality, tunnel.modelData.id)
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

    VitrailButton {
        variant: "tonal"
        icon: "settings"
        text: root.t("connection.vpn.global")
        onClicked: root.page.openGlobal()
    }
}
