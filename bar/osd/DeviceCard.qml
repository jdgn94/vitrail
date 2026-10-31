import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "../network"

// The card that opens beside the volume or microphone slider: every output
// (or input) device, the default one marked; a click makes a device the
// default.
ColumnLayout {
    id: root

    // OsdController: names the devices and sets the default.
    property var controller
    property bool output: true
    property var strings: ({})

    readonly property var devices: root.output ? root.controller.sinks : root.controller.sources
    readonly property var current: root.output ? root.controller.sink : root.controller.source

    spacing: VitrailTokens.gap("xs")

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailText {
        Layout.fillWidth: true
        Layout.leftMargin: VitrailTokens.gap("sm")
        variant: "label"
        text: root.t(root.output ? "osd.outputs" : "osd.inputs")
    }

    Scroller {
        Repeater {
            model: root.devices

            delegate: Entry {
                id: row

                required property var modelData

                width: parent.width
                icon: row.active ? "radio_button_checked" : "radio_button_unchecked"
                active: !!root.current && row.modelData.id === root.current.id
                title: root.controller.name(row.modelData)
                onTriggered: {
                    if (root.output)
                        root.controller.pickOutput(row.modelData)
                    else
                        root.controller.pickInput(row.modelData)
                }
            }
        }
    }
}
