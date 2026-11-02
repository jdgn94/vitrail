import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/launcher/query.js" as Query

// Launcher category: how the search behaves and what it remembers. The bar
// reads these keys from launcher.ini; clearing history is a request (a
// timestamp the launcher acts on once), since this window cannot touch its
// state file.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "general"
    // The user's own bangs, as a list; kept in prefs.launcherBangs.
    property var userBangs: Query.parseBangs(page.prefs.launcherBangs)

    readonly property var enabled: String(page.prefs.launcherModes).split("|")
    readonly property bool draftValid: keyField.text.trim() !== "" && nameField.text.trim() !== "" && urlField.text.indexOf("%s") >= 0

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function toggleMode(mode, on) {
        var next = Query.MODES.filter(function (one) {
            return one === mode ? on : page.enabled.indexOf(one) >= 0
        })
        page.prefs.launcherModes = next.join("|")
    }

    function saveBangs(list) {
        page.prefs.launcherBangs = Query.serializeBangs(list)
    }

    function addBang() {
        var key = keyField.text.replace(/^!/, "").trim()
        var rest = page.userBangs.filter(function (bang) { return bang.key !== key })
        page.saveBangs(rest.concat([{ key: key, name: nameField.text.trim(), url: urlField.text.trim() }]))
        keyField.text = ""
        nameField.text = ""
        urlField.text = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "general", icon: "apps", label: page.t("launcher.section.general") },
                { key: "web", icon: "language", label: page.t("launcher.section.web") }
            ]
            current: page.tab
            foreground: page.palette.foreground
            accent: page.palette.primary
            onSelected: page.tab = key
        }

        Flickable {
            id: scroller

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: column

                width: parent.width
                spacing: VitrailTokens.gap("xl")

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "general"
                    icon: "apps"
                    title: page.t("launcher.section.general")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "grid_view"
                        label: page.t("launcher.view")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "grid", icon: "grid_view", label: page.t("launcher.view.grid") },
                                { key: "list", icon: "view_list", label: page.t("launcher.view.list") }
                            ]
                            current: page.prefs.launcherView
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.launcherView = key
                        }
                    }

                    Repeater {
                        model: Query.MODES

                        delegate: VitrailSettingRow {
                            id: mode

                            required property string modelData

                            icon: ({ web: "language", calc: "calculate", run: "terminal", files: "folder", windows: "web_asset",
                                     actions: "bolt", clipboard: "content_paste" })[mode.modelData]
                            label: page.t("launcher.mode." + mode.modelData)
                            description: page.t("launcher.prefix").replace("%1", Query.PREFIXES[mode.modelData])
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailSwitch {
                                checked: page.enabled.indexOf(mode.modelData) >= 0
                                foreground: page.palette.foreground
                                accent: page.palette.primary
                                onToggled: function (value) { page.toggleMode(mode.modelData, value) }
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "general"
                    icon: "history"
                    title: page.t("launcher.section.history")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "delete_sweep"
                        label: page.t("launcher.history.clear")
                        description: page.t("launcher.history.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: "tonal"
                            icon: "delete"
                            text: page.t("launcher.history.clear")
                            onClicked: page.prefs.launcherClear = String(Date.now())
                        }
                    }

                    VitrailSettingRow {
                        icon: "visibility"
                        label: page.t("launcher.hidden.show")
                        description: page.t("launcher.hidden.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailButton {
                            variant: "tonal"
                            icon: "visibility"
                            text: page.t("launcher.hidden.show")
                            onClicked: page.prefs.launcherClear = Date.now() + ":hidden"
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "web"
                    icon: "language"
                    title: page.t("launcher.section.web")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSelect {
                        Layout.fillWidth: true
                        label: page.t("launcher.engine")
                        options: Object.keys(Query.ENGINES).map(function (key) { return { key: key, label: Query.ENGINES[key].name } })
                        current: page.prefs.launcherEngine
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        panel: page.palette.surfaceHigh
                        onSelected: page.prefs.launcherEngine = key
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "web"
                    icon: "bolt"
                    title: page.t("launcher.section.bangs")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "info"
                        label: page.t("launcher.bangs.help")
                        description: Query.bangs("").map(function (bang) { return "!" + bang.key + " " + bang.name }).join(" · ")
                        foreground: page.palette.foreground
                        muted: page.palette.muted
                    }

                    Repeater {
                        model: page.userBangs

                        delegate: VitrailSettingRow {
                            id: custom

                            required property var modelData

                            icon: "travel_explore"
                            label: "!" + custom.modelData.key + " · " + custom.modelData.name
                            description: custom.modelData.url
                            foreground: page.palette.foreground
                            muted: page.palette.muted

                            VitrailButton {
                                variant: "text"
                                tone: "error"
                                icon: "delete"
                                onClicked: page.saveBangs(page.userBangs.filter(function (bang) { return bang.key !== custom.modelData.key }))
                            }
                        }
                    }

                    VitrailField {
                        id: keyField

                        Layout.fillWidth: true
                        label: page.t("launcher.bang.key")
                    }

                    VitrailField {
                        id: nameField

                        Layout.fillWidth: true
                        label: page.t("launcher.bang.name")
                    }

                    VitrailField {
                        id: urlField

                        Layout.fillWidth: true
                        label: page.t("launcher.bang.url")
                    }

                    VitrailButton {
                        variant: "flat"
                        icon: "add"
                        text: page.t("launcher.bang.add")
                        enabled: page.draftValid
                        onClicked: page.addBang()
                    }
                }
            }
        }
    }
}
