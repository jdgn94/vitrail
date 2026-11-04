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
    // The apps with an open stream: one row each, if the preference allows.
    readonly property var apps: root.output ? root.controller.outputApps : root.controller.inputApps
    readonly property bool showApps: root.output ? root.controller.showOutputApps
                                                 : root.controller.showInputApps
    readonly property bool hasApps: root.showApps && root.apps.length > 0

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

    // The apps that are playing (or using the microphone), one row each.
    VitrailText {
        Layout.fillWidth: true
        Layout.leftMargin: VitrailTokens.gap("sm")
        visible: root.hasApps
        variant: "label"
        text: root.t(root.output ? "osd.apps" : "osd.micApps")
    }

    Scroller {
        visible: root.hasApps
        visibleRows: 4

        Repeater {
            model: root.apps

            delegate: AppRow {
                required property var modelData

                width: parent.width
                group: modelData
                step: root.controller.appStep
                iconSource: root.controller.iconSource(modelData)
                tooltip: modelData.name
                onFocusRequested: root.controller.focusApp(modelData)
                onMuteRequested: root.controller.toggleAppMute(modelData)
                onMoved: function (value) { root.controller.setAppVolume(modelData, value / 100) }
            }
        }
    }
}
