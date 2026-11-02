import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/network/vpn.js" as Vpn
import "../vpnsettings.js" as VpnDoc
import "../vpnview.js" as View

// One connection's settings. Its name, provider, region and config file are
// hypraether's and read-only; the credential it uses is assigned through
// `hypraether-vpn credential assign`; whether the automatic choice may pick it
// is Vitrail's own (misc.ini); removing it deletes it from the tool.
Item {
    id: root

    // The Connection page: its state, `ask` and navigation.
    property var page

    readonly property var connection: root.page.tunnels.filter(function (one) { return one.id === root.page.vpnId })[0] || null
    readonly property string connectionId: root.connection ? root.connection.id : ""
    property bool removing: false

    function t(key) {
        return root.page.t(key)
    }

    // Closes what is open, else leaves the view.
    function dismiss() {
        if (root.removing)
            root.removing = false
        else
            root.page.back()
    }

    implicitHeight: body.implicitHeight
    Keys.onEscapePressed: root.dismiss()
    onVisibleChanged: {
        root.removing = false
        if (root.visible)
            root.forceActiveFocus()
    }

    ColumnLayout {
        id: body

        width: parent.width
        spacing: VitrailTokens.gap("xl")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: "arrow_back"
                onClicked: root.page.back()
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "title"
                elide: Text.ElideRight
                text: root.connection ? Vpn.title(root.connection.name) : ""
            }
        }

        Section {
            Layout.fillWidth: true
            icon: "vpn_key"
            title: root.t("connection.vpn.conn.details")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailField {
                Layout.fillWidth: true
                size: "sm"
                readOnly: true
                label: root.t("connection.vpn.conn.name")
                text: root.connection ? root.connection.name : ""
                onEscaped: root.dismiss()
            }

            VitrailField {
                Layout.fillWidth: true
                size: "sm"
                readOnly: true
                label: root.t("connection.vpn.conn.provider")
                text: root.connection ? Vpn.provider(root.connection) : ""
                onEscaped: root.dismiss()
            }

            VitrailField {
                Layout.fillWidth: true
                size: "sm"
                readOnly: true
                label: root.t("connection.vpn.conn.region")
                text: root.connection ? root.connection.region : ""
                onEscaped: root.dismiss()
            }

            VitrailField {
                Layout.fillWidth: true
                size: "sm"
                readOnly: true
                label: root.t("connection.vpn.conn.path")
                text: root.connection ? root.connection.config_path : ""
                onEscaped: root.dismiss()
            }
        }

        Section {
            Layout.fillWidth: true
            icon: "key"
            title: root.t("connection.vpn.credential")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                wrapMode: Text.WordWrap
                text: root.page.credentials.length === 0 ? root.t("connection.vpn.conn.noCredentials")
                                                         : root.t("connection.vpn.conn.credential.help")
            }

            VitrailSelect {
                Layout.fillWidth: true
                visible: root.page.credentials.length > 0
                enabled: root.page.idle
                label: root.t("connection.vpn.credential")
                options: root.page.credentials.map(function (one) { return { key: one.name, label: one.name } })
                current: root.connection ? root.connection.credential : ""
                foreground: root.page.palette.foreground
                accent: root.page.palette.primary
                onSelected: function (key) {
                    if (root.connection && key !== root.connection.credential)
                        root.page.ask(View.request("vpn-cred-assign", { name: key, ids: [root.connectionId] }))
                }
            }

            VitrailSettingRow {
                icon: "bolt"
                label: root.t("connection.vpn.conn.auto")
                description: root.t("connection.vpn.conn.auto.help")
                foreground: root.page.palette.foreground
                muted: root.page.palette.muted

                VitrailSwitch {
                    checked: VpnDoc.isAuto(root.page.doc, root.connectionId)
                    foreground: root.page.palette.foreground
                    accent: root.page.palette.primary
                    onToggled: function (value) { root.page.save(VpnDoc.setAuto(root.page.doc, root.connectionId, value)) }
                }
            }
        }

        Section {
            Layout.fillWidth: true
            icon: "delete"
            title: root.t("connection.vpn.conn.remove")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailButton {
                visible: !root.removing
                variant: "outlined"
                tone: "error"
                icon: "delete"
                text: root.t("connection.vpn.conn.remove")
                enabled: root.page.idle
                onClicked: root.removing = true
            }

            ConfirmRow {
                visible: root.removing
                message: root.t("connection.vpn.conn.removeConfirm").replace("%1", root.connection ? Vpn.title(root.connection.name) : "")
                confirmText: root.t("connection.vpn.remove")
                cancelText: root.t("dialog.cancel")
                onCancelled: root.removing = false
                onConfirmed: {
                    var gone = root.connectionId
                    root.removing = false
                    root.page.back()
                    root.page.ask("vpn-remove:" + gone)
                }
            }
        }
    }
}
