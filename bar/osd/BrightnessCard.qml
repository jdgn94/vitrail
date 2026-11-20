import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The card that opens beside the brightness slider with a right click: one
// slider per display. With a single monitor it says so — there is nothing else
// to move, and the main slider already covers it.
ColumnLayout {
    id: root

    // BrightnessState.
    property var light
    property var strings: ({})
    // Percent one wheel notch moves.
    property real step: VitrailTokens.osd.step

    spacing: VitrailTokens.gap("sm")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailText {
        Layout.fillWidth: true
        Layout.leftMargin: VitrailTokens.gap("sm")
        Layout.rightMargin: VitrailTokens.gap("sm")
        visible: root.light.devices.length <= 1
        variant: "content"
        color: VitrailTokens.color("muted")
        text: root.t("osd.displays.one")
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.light.devices.length > 1
        spacing: VitrailTokens.gap("sm")

        Repeater {
            model: root.light.devices

            delegate: VitrailSlider {
                id: row

                required property var modelData

                Layout.fillWidth: true
                Layout.leftMargin: VitrailTokens.gap("sm")
                Layout.rightMargin: VitrailTokens.gap("sm")
                label: row.modelData.name
                suffix: "%"
                from: 0
                to: 100
                wheelStep: root.step
                value: row.modelData.percent
                size: "sm"
                onMoved: function (value) { root.light.set(row.modelData.name, value) }
            }
        }
    }
}
