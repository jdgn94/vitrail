import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "colors.js" as Colors

// The colour tab: the current colour and its preview, the output format, a
// button that picks a colour from the screen, and the last ten colours.
// Choosing a swatch or picking a new one copies the colour in the chosen
// format; the tab stays open.
Item {
    id: root

    property var strings: ({})
    property var recent: []
    property string hex: ""
    property string format: "hex"
    property bool active: false

    signal copied(string text)
    signal pickRequested()
    signal formatPicked(string format)

    readonly property var color: Colors.parse(root.hex)
    readonly property string text: Colors.format(root.color, root.format)
    readonly property int swatch: 26

    implicitHeight: content.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function copyCurrent() {
        if (root.color)
            root.copied(root.text)
    }

    function choose(value) {
        if (!Colors.isColor(value))
            return
        root.hex = value
        root.copied(Colors.format(Colors.parse(value), root.format))
    }

    ColumnLayout {
        id: content

        width: parent.width
        spacing: VitrailTokens.gap("sm")

        // The format the colour is written in.
        VitrailSegmented {
            Layout.fillWidth: true
            current: root.format
            options: [
                { key: "hex", label: "HEX" },
                { key: "hex8", label: "HEX8" },
                { key: "rgb", label: "RGB" },
                { key: "rgba", label: "RGBA" },
                { key: "hsl", label: "HSL" },
                { key: "hsla", label: "HSLA" }
            ]
            onSelected: function (key) {
                root.formatPicked(key)
                root.copied(Colors.format(root.color, key))
            }
        }

        // The preview: the colour itself, its value in the chosen format and
        // the button that copies it again.
        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: VitrailTokens.radius * 0.5
                color: root.color ? root.hex : "transparent"
                border.width: 1
                border.color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                      VitrailTokens.color("foreground").b, 0.25)

                VitrailIcon {
                    anchors.centerIn: parent
                    visible: !root.color
                    icon: "palette"
                    size: "md"
                    tone: "secondary"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                VitrailText {
                    Layout.fillWidth: true
                    variant: "body"
                    elide: Text.ElideRight
                    text: root.color ? root.text : root.t("clipboard.color.none")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    elide: Text.ElideRight
                    text: root.color ? root.hex.toUpperCase() : ""
                }
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "content_copy"
                enabled: root.color !== null
                onClicked: root.copyCurrent()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "label"
                opacity: 0.7
                text: root.t("clipboard.color.recent")
            }

            VitrailButton {
                variant: "text"
                tone: "primary"
                size: "sm"
                icon: "colorize"
                text: root.t("clipboard.color.pick")
                onClicked: root.pickRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: root.recent

                delegate: Rectangle {
                    required property var modelData

                    implicitWidth: root.swatch
                    implicitHeight: root.swatch
                    radius: root.swatch / 2
                    color: modelData
                    border.width: modelData.toUpperCase() === root.hex.toUpperCase() ? 2 : 1
                    border.color: Qt.rgba(VitrailTokens.color("foreground").r, VitrailTokens.color("foreground").g,
                                          VitrailTokens.color("foreground").b,
                                          modelData.toUpperCase() === root.hex.toUpperCase() ? 0.8 : 0.25)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(modelData)
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
