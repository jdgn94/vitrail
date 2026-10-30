import QtQuick
import QtQuick.Layouts
import "../../kit"

// Appearance category: theme mode and surface material.
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
                            { key: "light", label: page.t("theme.light") },
                            { key: "dark", label: page.t("theme.dark") },
                            { key: "auto", label: page.t("theme.auto") }
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
                            { key: "solid", label: page.t("surface.solid") },
                            { key: "glass", label: page.t("surface.glass") }
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
