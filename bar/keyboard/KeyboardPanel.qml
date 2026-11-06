import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../network"
import "keyboard.js" as Keyboard

// The layout switcher: one row per layout of the added keyboards, with the
// keyboard names and the quick-switch combination in its description.
Item {
    id: root

    property var strings: ({})
    // The parsed `hyprctl devices -j`.
    property var keyboards: []

    signal layoutRequested(string layout)

    readonly property var rows: Keyboard.layoutRows(root.keyboards)

    implicitWidth: 340
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
                variant: "icon"
                icon: "keyboard"
                color: VitrailTokens.color("primary")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                VitrailText {
                    variant: "subtitle"
                    text: root.t("keyboard.layouts")
                }

                VitrailText {
                    Layout.fillWidth: true
                    variant: "label"
                    opacity: 0.7
                    wrapMode: Text.Wrap
                    text: root.t("keyboard.layouts.help")
                }
            }
        }

        VitrailText {
            Layout.fillWidth: true
            visible: root.rows.length === 0
            variant: "content"
            text: root.t("keyboard.none")
        }

        Repeater {
            model: root.rows

            delegate: Entry {
                required property var modelData

                Layout.fillWidth: true
                icon: "language"
                title: modelData.title
                subtitle: modelData.subtitle
                active: modelData.active
                onTriggered: root.layoutRequested(modelData.key)
            }
        }
    }
}
