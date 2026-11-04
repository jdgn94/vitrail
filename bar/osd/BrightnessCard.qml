import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The card that opens beside the brightness slider when there is more than
// one monitor: one slider each. (The main slider moves them all.)
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
        variant: "label"
        text: root.t("osd.displays")
    }

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
