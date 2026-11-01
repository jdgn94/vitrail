import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../bar/media"

// Plugins category: the player's look, then every plugin found by
// `vitrail plugins index`, rendered inside a card. Plugins are trusted code:
// they run in this process.
Item {
    id: page

    property var palette
    property var prefs
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
                icon: "music_note"
                title: page.t("plugins.section.media")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "album"
                    label: page.t("plugins.mediaStyle")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    // Two previews instead of a switch: each shows the look it
                    // picks, and the chosen one is shaded.
                    RowLayout {
                        spacing: VitrailTokens.gap("sm")

                        Repeater {
                            model: [
                                { key: "disc", label: page.t("plugins.mediaStyle.disc") },
                                { key: "cassette", label: page.t("plugins.mediaStyle.cassette") }
                            ]

                            delegate: Rectangle {
                                id: tile

                                required property var modelData

                                readonly property bool chosen: page.prefs.mediaStyle === tile.modelData.key

                                implicitWidth: look.implicitWidth + 2 * VitrailTokens.gap("md")
                                implicitHeight: look.implicitHeight + 2 * VitrailTokens.gap("sm")
                                radius: VitrailTokens.radius * 0.6
                                color: tile.chosen
                                       ? Qt.rgba(page.palette.primary.r, page.palette.primary.g,
                                                 page.palette.primary.b, 0.18)
                                       : "transparent"
                                border.width: 1
                                border.color: tile.chosen
                                              ? page.palette.primary
                                              : Qt.rgba(page.palette.foreground.r, page.palette.foreground.g,
                                                         page.palette.foreground.b, 0.18)

                                // The look itself, as the player draws it (paused),
                                // scaled to fit its slot, with its name under it.
                                ColumnLayout {
                                    id: look

                                    anchors.centerIn: parent
                                    spacing: VitrailTokens.gap("xs")

                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: VitrailTokens.media.preview.width
                                        implicitHeight: VitrailTokens.media.preview.height

                                        // The settings window's own palette: this
                                        // page's `kit` is not the bar's.
                                        DiscArt {
                                            anchors.centerIn: parent
                                            primary: page.palette.primary
                                            foreground: page.palette.foreground
                                            surface: page.palette.surface
                                            scale: VitrailTokens.media.preview.disc
                                            visible: tile.modelData.key === "disc"
                                        }

                                        CassetteArt {
                                            anchors.centerIn: parent
                                            dark: page.palette.dark
                                            foreground: page.palette.foreground
                                            surface: page.palette.surface
                                            surfaceHigh: page.palette.surfaceHigh
                                            primary: page.palette.primary
                                            info: page.palette.info
                                            scale: VitrailTokens.media.preview.cassette
                                            visible: tile.modelData.key === "cassette"
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: tile.modelData.label
                                        color: tile.chosen ? page.palette.primary : page.palette.foreground
                                        font.pixelSize: VitrailTokens.size("label")
                                        font.family: VitrailTokens.fontFamily
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.prefs.mediaStyle = tile.modelData.key
                                }
                            }
                        }
                    }
                }
            }

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
