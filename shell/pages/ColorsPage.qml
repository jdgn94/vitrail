import QtQuick
import QtQuick.Layouts
import "../../kit"

// Colors category: the palette extracted from the wallpaper.
Item {
    id: page

    property var palette
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
        }
    }
}
