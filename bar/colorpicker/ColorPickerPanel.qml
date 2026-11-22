import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "colorpicker.js" as ColorPicker

// The colour picker element's popup: the recent colours as a bounded grid of
// swatches with their hex, each one copying on a click, and a button that
// opens the palette (the same `Super+P` panel). The gear opens the element's
// block in Settings.
Item {
    id: root

    property var strings: ({})
    // The recent colours, newest first, as the shell read `colorpickerColors`.
    property var colors: []
    // How many to show (`colorpickerRecent`, 4–24).
    property int limit: ColorPicker.DEFAULT

    signal settingsRequested()
    // A swatch was clicked: the shell copies it, without touching the history.
    signal copyRequested(string hex)
    signal paletteRequested()

    readonly property var list: (Array.isArray(root.colors) ? root.colors : [])
                                  .slice(0, ColorPicker.cap(root.limit))
    readonly property int swatch: VitrailTokens.size("display")
    readonly property real cellWidth: root.swatch * 2

    implicitWidth: 380
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.colorpicker")
            }

            VitrailText {
                variant: "label"
                opacity: 0.7
                text: root.list.length
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        VitrailText {
            Layout.fillWidth: true
            variant: "label"
            opacity: 0.7
            text: root.t("bar.colorpicker.recent")
        }

        VitrailText {
            objectName: "empty"

            Layout.fillWidth: true
            visible: root.list.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.colorpicker.empty")
        }

        Flow {
            Layout.fillWidth: true
            visible: root.list.length > 0
            spacing: VitrailTokens.gap("sm")

            Repeater {
                model: root.list

                delegate: Item {
                    id: cell

                    required property var modelData

                    objectName: "colorSwatch"

                    width: root.cellWidth
                    height: root.swatch * 1.25 + VitrailTokens.size("label") * 1.8

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.swatch * 1.25
                        height: width
                        radius: width / 2
                        color: cell.modelData
                        border.width: 1
                        border.color: Qt.rgba(VitrailTokens.color("foreground").r,
                                              VitrailTokens.color("foreground").g,
                                              VitrailTokens.color("foreground").b, 0.25)
                    }

                    VitrailText {
                        objectName: "colorHex"

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        variant: "label"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: cell.modelData
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.copyRequested(ColorPicker.hex(cell.modelData))
                    }
                }
            }
        }

        VitrailButton {
            objectName: "openPalette"

            Layout.fillWidth: true
            variant: "tonal"
            tone: "primary"
            icon: "palette"
            text: root.t("bar.colorpicker.open")
            onClicked: root.paletteRequested()
        }
    }
}
