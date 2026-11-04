import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../vpnview.js" as View

// The VPN settings that belong to hypraether-vpn as a whole: the traffic mode,
// connecting at startup (its `enabled` marker), the URL list (its domain list),
// the credentials (name, user name, password) and, below, the import form
// (`VpnImport`).
// Passwords go through `page.sendSecret` and never stay in this view.
Item {
    id: root

    // The Connection page: its state, `ask` and navigation.
    property var page

    // The credential being edited or removed, and the URL group that is open.
    property string editing: ""
    property string removing: ""
    property string openGroup: ""
    readonly property bool secretsOk: root.page.runtime !== ""

    function t(key) {
        return root.page.t(key)
    }

    // Closes what is open, else leaves the view.
    function dismiss() {
        if (root.removing !== "")
            root.removing = ""
        else if (root.editing !== "")
            root.editing = ""
        else
            root.page.back()
    }

    function fail(field, key) {
        field.errorText = root.t(key)
        field.error = true
        field.shake()
    }

    function addUrl() {
        var url = View.normalizeUrl(urlField.text)
        if (url === "") {
            root.fail(urlField, "connection.vpn.url.invalid")
            return
        }
        urlField.text = ""
        root.page.ask("vpn-domain-add:" + url)
    }

    function addCredential() {
        var name = credName.text.trim()
        var taken = root.page.credentials.some(function (one) { return one.name === name })
        if (name === "" || taken) {
            root.fail(credName, name === "" ? "connection.vpn.credential.required" : "connection.vpn.credential.duplicate")
            return
        }
        if (credUser.text.trim() === "") {
            root.fail(credUser, "connection.vpn.credential.required")
            return
        }
        if (credPassword.text === "") {
            root.fail(credPassword, "connection.vpn.credential.required")
            return
        }
        root.page.sendSecret("vpn-cred-add", { name: name, user: credUser.text.trim() }, credPassword.text)
        credName.text = ""
        credUser.text = ""
        credPassword.text = ""
        credPassword.revealed = false
    }

    implicitHeight: body.implicitHeight
    Keys.onEscapePressed: root.dismiss()
    onVisibleChanged: {
        root.editing = ""
        root.removing = ""
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
                text: root.t("connection.vpn.global")
            }
        }

        // --- traffic mode and startup ---------------------------------------
        Section {
            Layout.fillWidth: true
            icon: "alt_route"
            title: root.t("connection.vpn.mode")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailSegmented {
                options: [
                    { key: "split", icon: "call_split", label: root.t("connection.vpn.mode.split") },
                    { key: "full", icon: "public", label: root.t("connection.vpn.mode.full") }
                ]
                current: root.page.mode
                enabled: root.page.idle
                foreground: root.page.palette.foreground
                accent: root.page.palette.primary
                onSelected: function (key) {
                    if (key !== root.page.mode)
                        root.page.ask("vpn-mode:" + key)
                }
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                wrapMode: Text.WordWrap
                text: root.t("connection.vpn.mode.help")
            }

            VitrailSettingRow {
                Layout.topMargin: VitrailTokens.gap("sm")
                icon: "power_settings_new"
                label: root.t("connection.vpn.startup")
                description: root.t("connection.vpn.startup.help")
                foreground: root.page.palette.foreground
                muted: root.page.palette.muted

                VitrailSwitch {
                    checked: root.page.enabled
                    enabled: root.page.idle && root.page.tunnels.length > 0
                    foreground: root.page.palette.foreground
                    accent: root.page.palette.primary
                    onToggled: function (value) { root.page.ask(value ? "vpn-best" : "vpn-off") }
                }
            }
        }

        // --- URLs ------------------------------------------------------------
        Section {
            Layout.fillWidth: true
            icon: "language"
            title: root.t("connection.vpn.urls")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                wrapMode: Text.WordWrap
                text: root.t("connection.vpn.urls.help")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: VitrailTokens.gap("sm")

                VitrailField {
                    id: urlField

                    Layout.fillWidth: true
                    size: "sm"
                    label: root.t("connection.vpn.url.field")
                    placeholder: "https://example.com"
                    onAccepted: if (root.page.idle) root.addUrl()
                    onEscaped: root.dismiss()
                    onTextChanged: urlField.error = false
                }

                VitrailButton {
                    variant: "flat"
                    icon: "add"
                    text: root.t("action.add")
                    busy: root.page.busy.indexOf("vpn-domain-add:") === 0
                    enabled: root.page.idle && urlField.text.trim() !== ""
                    onClicked: root.addUrl()
                }
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.page.domains.length === 0
                variant: "content"
                text: root.t("connection.vpn.urls.empty")
            }

            Repeater {
                model: View.groupDomains(root.page.domains)

                delegate: ColumnLayout {
                    id: group

                    required property var modelData

                    readonly property bool open: root.openGroup === group.modelData.root

                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("xs")

                    VitrailSettingRow {
                        icon: "language"
                        label: group.modelData.root
                        description: root.t("connection.vpn.url.counts").replace("%1", group.modelData.count)
                                         .replace("%2", group.modelData.ips)
                        foreground: root.page.palette.foreground
                        muted: root.page.palette.muted

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            icon: group.open ? "expand_less" : "expand_more"
                            onClicked: root.openGroup = group.open ? "" : group.modelData.root
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("xl")
                        visible: group.open
                        spacing: VitrailTokens.gap("xs")

                        Repeater {
                            model: group.modelData.domains

                            delegate: VitrailSettingRow {
                                id: entry

                                required property var modelData

                                label: entry.modelData.domain
                                description: root.t("connection.vpn.url.addresses").replace("%1", entry.modelData.ips)
                                foreground: root.page.palette.foreground
                                muted: root.page.palette.muted

                                VitrailButton {
                                    variant: "text"
                                    tone: "error"
                                    icon: "delete"
                                    busy: root.page.busy === "vpn-domain-remove:" + entry.modelData.domain
                                    enabled: root.page.idle
                                    onClicked: root.page.ask("vpn-domain-remove:" + entry.modelData.domain)
                                }
                            }
                        }
                    }
                }
            }

            VitrailSettingRow {
                icon: "refresh"
                label: root.t("connection.vpn.url.refresh")
                description: root.t("connection.vpn.url.refresh.help")
                foreground: root.page.palette.foreground
                muted: root.page.palette.muted

                VitrailButton {
                    variant: "tonal"
                    icon: "refresh"
                    text: root.t("connection.vpn.url.refresh")
                    busy: root.page.busy === "vpn-domain-refresh"
                    enabled: root.page.idle && root.page.domains.length > 0
                    onClicked: root.page.ask("vpn-domain-refresh")
                }
            }
        }

        // --- credentials -----------------------------------------------------
        Section {
            Layout.fillWidth: true
            icon: "key"
            title: root.t("connection.vpn.credentials")
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary

            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                wrapMode: Text.WordWrap
                text: root.t("connection.vpn.credentials.help")
            }

            VitrailText {
                Layout.fillWidth: true
                visible: root.page.credentials.length === 0
                variant: "content"
                text: root.t("connection.vpn.credentials.empty")
            }

            VitrailText {
                Layout.fillWidth: true
                visible: !root.secretsOk
                variant: "content"
                color: root.page.palette.error
                wrapMode: Text.WordWrap
                text: root.t("connection.vpn.credential.noFolder")
            }

            Repeater {
                model: root.page.credentials

                delegate: ColumnLayout {
                    id: credential

                    required property var modelData

                    readonly property bool editOpen: root.editing === credential.modelData.name
                    readonly property bool removeOpen: root.removing === credential.modelData.name
                    function save() {
                        var change = View.updatePayload(credential.modelData, editName.text, editUser.text)
                        var password = editPassword.text
                        if (change !== null && change.rename !== undefined
                                && root.page.credentials.some(function (one) { return one.name === change.rename })) {
                            root.fail(editName, "connection.vpn.credential.duplicate")
                            return
                        }
                        root.editing = ""
                        editPassword.text = ""
                        if (change === null && password === "")
                            return
                        change = change || { name: credential.modelData.name }
                        if (password !== "")
                            root.page.sendSecret("vpn-cred-update", change, password)
                        else
                            root.page.ask(View.request("vpn-cred-update", change))
                    }

                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailSettingRow {
                        icon: "key"
                        label: credential.modelData.name
                        description: root.page.parts([
                            credential.modelData.username,
                            root.t("connection.vpn.credential.usedBy").replace("%1", credential.modelData.usedBy)
                        ])
                        foreground: root.page.palette.foreground
                        muted: root.page.palette.muted

                        VitrailButton {
                            variant: "plain"
                            tone: "secondary"
                            icon: credential.editOpen ? "expand_less" : "edit"
                            onClicked: {
                                root.removing = ""
                                root.editing = credential.editOpen ? "" : credential.modelData.name
                            }
                        }

                        VitrailButton {
                            variant: "text"
                            tone: "error"
                            icon: "delete"
                            enabled: root.page.idle
                            onClicked: {
                                root.editing = ""
                                root.removing = credential.modelData.name
                            }
                        }
                    }

                    ConfirmRow {
                        visible: credential.removeOpen
                        message: root.t("connection.vpn.credential.removeConfirm").replace("%1", credential.modelData.name)
                        confirmText: root.t("connection.vpn.remove")
                        cancelText: root.t("dialog.cancel")
                        onCancelled: root.removing = ""
                        onConfirmed: {
                            root.removing = ""
                            root.page.ask("vpn-cred-remove:" + credential.modelData.name)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("xl")
                        visible: credential.editOpen
                        spacing: VitrailTokens.gap("sm")

                        VitrailField {
                            id: editName

                            Layout.fillWidth: true
                            size: "sm"
                            label: root.t("connection.vpn.credential.name")
                            text: credential.modelData.name
                            onAccepted: credential.save()
                            onEscaped: root.dismiss()
                            onTextChanged: editName.error = false
                        }

                        VitrailField {
                            id: editUser

                            Layout.fillWidth: true
                            size: "sm"
                            label: root.t("connection.vpn.credential.user")
                            text: credential.modelData.username
                            onAccepted: credential.save()
                            onEscaped: root.dismiss()
                        }

                        VitrailField {
                            id: editPassword

                            Layout.fillWidth: true
                            size: "sm"
                            type: "password"
                            enabled: root.secretsOk
                            label: root.t("connection.vpn.credential.newPassword")
                            supportingText: root.t("connection.vpn.credential.newPassword.help")
                            onAccepted: credential.save()
                            onEscaped: root.dismiss()
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("sm")

                            Item { Layout.fillWidth: true }

                            VitrailButton {
                                variant: "outlined"
                                tone: "secondary"
                                text: root.t("dialog.cancel")
                                onClicked: {
                                    editPassword.text = ""
                                    root.editing = ""
                                }
                            }

                            VitrailButton {
                                variant: "flat"
                                text: root.t("action.save")
                                enabled: root.page.idle
                                onClicked: credential.save()
                            }
                        }
                    }
                }
            }

            VitrailText {
                Layout.topMargin: VitrailTokens.gap("md")
                variant: "subtitle"
                text: root.t("connection.vpn.credential.add")
            }

            VitrailField {
                id: credName

                Layout.fillWidth: true
                size: "sm"
                label: root.t("connection.vpn.credential.name")
                onAccepted: credUser.forceActiveFocus()
                onEscaped: root.dismiss()
                onTextChanged: credName.error = false
            }

            VitrailField {
                id: credUser

                Layout.fillWidth: true
                size: "sm"
                label: root.t("connection.vpn.credential.user")
                onAccepted: credPassword.forceActiveFocus()
                onEscaped: root.dismiss()
                onTextChanged: credUser.error = false
            }

            VitrailField {
                id: credPassword

                Layout.fillWidth: true
                size: "sm"
                type: "password"
                enabled: root.secretsOk
                label: root.t("connection.vpn.credential.password")
                onAccepted: if (root.page.idle) root.addCredential()
                onEscaped: root.dismiss()
                onTextChanged: credPassword.error = false
            }

            VitrailButton {
                variant: "flat"
                icon: "add"
                text: root.t("connection.vpn.credential.add")
                busy: root.page.busy.indexOf("vpn-cred-add:") === 0
                enabled: root.page.idle && root.secretsOk
                onClicked: root.addCredential()
            }
        }

        // --- import ----------------------------------------------------------
        VpnImport {
            Layout.fillWidth: true
            page: root.page
            onEscaped: root.dismiss()
        }
    }
}
