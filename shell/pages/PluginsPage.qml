import QtQuick
import QtQuick.Layouts
import "../../kit"

// Plugins category: every plugin found by `vitrail plugins index`, rendered
// inside a card. Plugins are trusted code: they run in this process.
Item {
    id: page

    property var palette
    property var plugins: []
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
                icon: "extension"
                title: page.t("plugins.section.installed")
                foreground: page.palette.foreground
                accent: page.palette.primary

                Text {
                    Layout.fillWidth: true
                    text: page.t("plugins.help")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }

                VitrailSettingRow {
                    visible: page.plugins.length === 0
                    icon: "extension_off"
                    label: page.t("plugins.empty")
                    foreground: page.palette.foreground
                    muted: page.palette.muted
                }

                Repeater {
                    model: page.plugins

                    delegate: Rectangle {
                        id: card

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: body.implicitHeight + 2 * VitrailTokens.gap("md")
                        radius: VitrailTokens.radius
                        color: Qt.rgba(page.palette.surfaceHigh.r, page.palette.surfaceHigh.g, page.palette.surfaceHigh.b, 0.55)
                        border.width: 1
                        border.color: page.palette.outline

                        ColumnLayout {
                            id: body

                            x: VitrailTokens.gap("md")
                            y: VitrailTokens.gap("md")
                            width: card.width - 2 * VitrailTokens.gap("md")
                            spacing: VitrailTokens.gap("sm")

                            VitrailSettingRow {
                                icon: "extension"
                                label: card.modelData.name + "  " + card.modelData.version
                                description: card.modelData.description
                                foreground: page.palette.foreground
                                muted: page.palette.muted
                            }

                            Loader {
                                Layout.fillWidth: true
                                source: "file://" + card.modelData.entry
                            }
                        }
                    }
                }
            }
        }
    }
}
