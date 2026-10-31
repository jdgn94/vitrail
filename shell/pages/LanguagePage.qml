import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Language category: applies on save, not live.
Item {
    id: page

    property var palette
    property var prefs
    property var draft
    property var languages: []
    property var strings

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            Section {
                Layout.fillWidth: true
                icon: "translate"
                title: page.t("section.language")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSelect {
                    Layout.fillWidth: true
                    label: page.t("language.label")
                    options: page.languages
                    current: page.draft.language
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    panel: page.palette.surfaceHigh
                    onSelected: page.draft.language = key
                }

                VitrailSettingRow {
                    icon: "settings_suggest"
                    label: page.t("language.system")
                    description: page.t("language.system.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        checked: page.prefs.languageSystem
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.languageSystem = value }
                    }
                }

                VitrailSettingRow {
                    icon: "restart_alt"
                    label: page.t("language.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailButton {
                        variant: "flat"
                        icon: "save"
                        text: page.t("action.save")
                        onClicked: page.prefs.language = page.draft.language
                    }
                }
            }
        }
    }
}
