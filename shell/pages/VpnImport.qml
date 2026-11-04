import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../vpnview.js" as View

// The form that imports an OpenVPN file as a connection: the file (typed or
// picked), an optional name, the credential it uses and whether the original
// is deleted once Vitrail's private copy is verified. Used by the global VPN
// settings and by the VPN tab's own "Add VPN" view.
Section {
    id: root

    // The Connection page: its state, `ask` and navigation.
    property var page

    // The credential an import takes: null until picked (the first one then),
    // "" for none. `moveFile` deletes the picked file once its copy is stored.
    property var chosen: null
    property bool moveFile: false
    readonly property string importCredential: root.chosen !== null ? root.chosen
                                              : root.page.credentials.length > 0 ? root.page.credentials[0].name : ""

    // Escape in a field, and a request that was sent.
    signal escaped()
    signal imported()

    function t(key) {
        return root.page.t(key)
    }

    function fail(field, key) {
        field.errorText = root.t(key)
        field.error = true
        field.shake()
    }

    function importFile() {
        var path = View.filePath(importPath.text)
        if (path === "" || !View.hasExtension(path)) {
            root.fail(importPath, "connection.vpn.import.invalid")
            return
        }
        root.page.ask(View.importRequest(path, importName.text, root.importCredential, root.moveFile))
        importPath.text = ""
        importName.text = ""
        root.imported()
    }

    icon: "upload_file"
    title: root.t("connection.vpn.import")
    foreground: root.page.palette.foreground
    accent: root.page.palette.primary

    FileDialog {
        id: chooser

        title: root.t("connection.vpn.import.dialog")
        nameFilters: [root.t("connection.vpn.import.filter") + " (*.ovpn *.conf)", root.t("connection.vpn.import.all") + " (*)"]
        onAccepted: {
            importPath.text = View.filePath(chooser.selectedFile)
            importPath.error = false
        }
    }

    VitrailText {
        Layout.fillWidth: true
        variant: "content"
        wrapMode: Text.WordWrap
        text: root.t("connection.vpn.import.help")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("sm")

        VitrailField {
            id: importPath

            Layout.fillWidth: true
            size: "sm"
            label: root.t("connection.vpn.import.file")
            placeholder: "/home/me/server.ovpn"
            onAccepted: if (root.page.idle) root.importFile()
            onEscaped: root.escaped()
            onTextChanged: importPath.error = false
        }

        VitrailButton {
            variant: "tonal"
            icon: "folder_open"
            text: root.t("connection.vpn.import.browse")
            onClicked: chooser.open()
        }
    }

    VitrailField {
        id: importName

        Layout.fillWidth: true
        size: "sm"
        label: root.t("connection.vpn.import.name")
        onAccepted: if (root.page.idle) root.importFile()
        onEscaped: root.escaped()
    }

    VitrailSelect {
        Layout.fillWidth: true
        enabled: root.page.idle
        label: root.t("connection.vpn.credential")
        options: [{ key: "", label: root.t("connection.vpn.import.noCredential") }].concat(
                     root.page.credentials.map(function (one) { return { key: one.name, label: one.name } }))
        current: root.importCredential
        foreground: root.page.palette.foreground
        accent: root.page.palette.primary
        onSelected: function (key) { root.chosen = key }
    }

    VitrailSettingRow {
        icon: "drive_file_move"
        label: root.t("connection.vpn.import.move")
        description: root.t("connection.vpn.import.move.help")
        foreground: root.page.palette.foreground
        muted: root.page.palette.muted

        VitrailSwitch {
            checked: root.moveFile
            foreground: root.page.palette.foreground
            accent: root.page.palette.primary
            onToggled: function (value) { root.moveFile = value }
        }
    }

    VitrailButton {
        variant: "flat"
        icon: "upload_file"
        text: root.t("connection.vpn.import.run")
        busy: root.page.busy.indexOf("vpn-import:") === 0
        enabled: root.page.idle && importPath.text.trim() !== ""
        onClicked: root.importFile()
    }
}
