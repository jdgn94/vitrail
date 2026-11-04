import QtQuick
import QtQuick.Layouts
import "../../kit"

// Colors category: the palette extracted from the wallpaper.
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
                icon: "palette"
                title: page.t("palette.source")
                foreground: page.palette.foreground
                accent: page.palette.primary

                Repeater {
                    model: [
                        { icon: "colorize", label: page.t("palette.primary"), value: page.palette.primary },
                        { icon: "layers", label: page.t("palette.surface"), value: page.palette.surface },
                        { icon: "stacks", label: page.t("palette.surfaceHigh"), value: page.palette.surfaceHigh },
                        { icon: "format_color_text", label: page.t("palette.onSurface"), value: page.palette.foreground }
                    ]

                    delegate: VitrailSettingRow {
                        id: swatch

                        required property var modelData

                        icon: swatch.modelData.icon
                        label: swatch.modelData.label
                        description: swatch.modelData.value.toString().toUpperCase()
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 28
                            radius: 7
                            color: swatch.modelData.value
                            border.width: 1
                            border.color: page.palette.outline
                        }
                    }
                }
            }

            Section {
                Layout.fillWidth: true
                icon: "palette"
                title: page.t("palette.scheme")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "style"
                    label: page.t("palette.scheme")
                    description: page.t("palette.scheme.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSelect {
                        Layout.preferredWidth: 220
                        current: page.prefs.colorScheme
                        options: ["tonal", "content", "expressive", "fidelity", "vibrant",
                                  "neutral", "monochrome", "rainbow", "fruit-salad", "smart"]
                                 .map(function (key) {
                                     return { key: key, label: page.t("palette.scheme." + key) }
                                 })
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        panel: page.palette.surfaceHigh
                        onSelected: page.prefs.colorScheme = key
                    }
                }

                VitrailSettingRow {
                    icon: "contrast"
                    label: page.t("palette.contrast")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSegmented {
                        options: [
                            { key: "-1", label: page.t("palette.contrast.low") },
                            { key: "0", label: page.t("palette.contrast.standard") },
                            { key: "1", label: page.t("palette.contrast.high") }
                        ]
                        current: String(page.prefs.colorContrast)
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onSelected: page.prefs.colorContrast = Number(key)
                    }
                }
            }
        }
    }
}
