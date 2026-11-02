import QtQuick
import QtQuick.Layouts
import "../../kit"

// Appearance category: theme mode and surface material.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "theme"

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "theme", icon: "palette", label: page.t("section.theme") },
                { key: "surface", icon: "layers", label: page.t("section.surface") }
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
                    visible: page.tab === "theme"
                    icon: "contrast"
                    title: page.t("section.theme")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "dark_mode"
                        label: page.t("theme.mode")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "light", icon: "light_mode", label: page.t("theme.light") },
                                { key: "dark", icon: "dark_mode", label: page.t("theme.dark") },
                                { key: "auto", icon: "contrast", label: page.t("theme.auto") }
                            ]
                            current: page.prefs.appearance
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.appearance = key
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "surface"
                    icon: "layers"
                    title: page.t("section.surface")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "blur_on"
                        label: page.t("surface.material")
                        description: page.t("surface.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            options: [
                                { key: "solid", icon: "square", label: page.t("surface.solid") },
                                { key: "glass", icon: "blur_on", label: page.t("surface.glass") }
                            ]
                            current: page.prefs.surfaceStyle
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.surfaceStyle = key
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("surface.opacity")
                        suffix: "%"
                        from: 20
                        to: 100
                        stepSize: 1
                        value: page.prefs.surfaceOpacity * 100
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.surfaceOpacity = value / 100
                    }
                }
            }
        }
    }
}
