import QtQuick
import QtQuick.Layouts
import "../../kit"

// Terminal category: kitty's tab bar and typography.
// Values land in settings.ini; apply-settings.sh turns them into
// ~/.config/vitrail/header.conf and ~/.config/vitrail/kitty-user.conf.
Item {
    id: page

    property var palette
    property var prefs
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
                icon: "tab"
                title: page.t("terminal.section.tabs")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "style"
                    label: page.t("terminal.tabStyle")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSegmented {
                        options: [
                            { key: "capsule", label: page.t("terminal.capsule") },
                            { key: "tonal", label: page.t("terminal.tonal") },
                            { key: "minimal", label: page.t("terminal.minimal") }
                        ]
                        current: page.prefs.tabStyle
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.prefs.tabStyle = key
                    }
                }

                VitrailSettingRow {
                    icon: "apps"
                    label: page.t("terminal.icons")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        checked: page.prefs.tabIcons
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.tabIcons = value }
                    }
                }

                VitrailSettingRow {
                    icon: "format_list_numbered"
                    label: page.t("terminal.numbers")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        checked: page.prefs.tabNumbers
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.tabNumbers = value }
                    }
                }
            }

            Section {
                Layout.fillWidth: true
                icon: "terminal"
                title: page.t("terminal.section.look")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "palette"
                    label: page.t("terminal.scheme")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSegmented {
                        options: [
                            { key: "system", label: page.t("terminal.system") },
                            { key: "light", label: page.t("theme.light") },
                            { key: "dark", label: page.t("theme.dark") }
                        ]
                        current: page.prefs.terminalScheme
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.prefs.terminalScheme = key
                    }
                }

                VitrailSlider {
                    Layout.fillWidth: true
                    label: page.t("terminal.fontSize")
                    suffix: " px"
                    from: 8
                    to: 20
                    stepSize: 1
                    value: page.prefs.fontSize
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.fontSize = value
                }

                VitrailSlider {
                    Layout.fillWidth: true
                    label: page.t("terminal.padding")
                    suffix: " px"
                    from: 0
                    to: 24
                    stepSize: 1
                    value: page.prefs.terminalPadding
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.terminalPadding = value
                }

                Text {
                    Layout.fillWidth: true
                    text: page.t("terminal.help")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
