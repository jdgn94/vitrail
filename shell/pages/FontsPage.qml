import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../fontsview.js" as FontsView

// Fonts category: one page for the whole session's type, the shell's icons,
// the apps' icon pack and the pointer. The lists are what `vitrail.fonts
// state` found on this machine; the apply script writes the choice to
// fontconfig, GTK, qt6ct, kitty, the Hyprland cursor and environment.d.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property var fonts: ({ fonts: [], monospace: [], iconThemes: [], cursorThemes: [] })
    property string tab: "text"

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function options(names, current) {
        return FontsView.options(names || [], current || "")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "text", icon: "font_download", label: page.t("fonts.tab.text") },
                { key: "icons", icon: "apps", label: page.t("fonts.tab.icons") },
                { key: "cursor", icon: "mouse", label: page.t("fonts.tab.cursor") }
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
                    visible: page.tab === "text"
                    icon: "font_download"
                    title: page.t("fonts.section.text")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "text_fields"
                        label: page.t("fonts.system")
                        description: page.t("fonts.system.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 260
                            current: page.prefs.fontSystem
                            options: page.options(page.fonts.fonts, page.prefs.fontSystem)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.fontSystem = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "terminal"
                        label: page.t("fonts.console")
                        description: page.t("fonts.console.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 260
                            current: page.prefs.fontConsole
                            options: page.options(page.fonts.monospace, page.prefs.fontConsole)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.fontConsole = key
                        }
                    }

                    VitrailText {
                        Layout.fillWidth: true
                        Layout.leftMargin: VitrailTokens.gap("md")
                        variant: "subtitle"
                        family: page.prefs.fontSystem
                        text: page.t("fonts.preview")
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "icons"
                    icon: "apps"
                    title: page.t("fonts.section.icons")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "interests"
                        label: page.t("fonts.uiIcons")
                        description: page.t("fonts.uiIcons.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "rounded", label: page.t("fonts.uiIcons.rounded") },
                                { key: "sharp", label: page.t("fonts.uiIcons.sharp") },
                                { key: "outlined", label: page.t("fonts.uiIcons.outlined") }
                            ]
                            current: page.prefs.uiIcons
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.uiIcons = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "widgets"
                        label: page.t("fonts.iconTheme")
                        description: page.t("fonts.iconTheme.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 260
                            current: page.prefs.iconTheme
                            options: page.options(page.fonts.iconThemes, page.prefs.iconTheme)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.iconTheme = key
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "cursor"
                    icon: "mouse"
                    title: page.t("fonts.section.cursor")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "ads_click"
                        label: page.t("fonts.cursor")
                        description: page.t("fonts.cursor.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSelect {
                            Layout.preferredWidth: 260
                            current: page.prefs.cursorTheme
                            options: page.options(page.fonts.cursorThemes, page.prefs.cursorTheme)
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            panel: page.palette.surfaceHigh
                            onSelected: page.prefs.cursorTheme = key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("fonts.cursorSize")
                        suffix: " px"
                        from: VitrailTokens.ranges.cursor.min
                        to: VitrailTokens.ranges.cursor.max
                        stepSize: VitrailTokens.ranges.cursor.step
                        value: page.prefs.cursorSize
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.cursorSize = value
                    }
                }
            }
        }
    }
}
