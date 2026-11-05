import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// Screenshots and recording for the panel's widgets slot. The commands belong
// to the shell (`captureShot`, `toggleRecording`); this only reports the
// choice. Region first: it is the mode a shortcut-less panel is for.
RowLayout {
    id: root

    property bool recording: false
    // sm / md / lg: the buttons grow with the panel widget's size.
    property string size: "md"

    signal shotRequested(string mode)
    signal recordRequested()

    spacing: VitrailTokens.gap("xs")

    function iconOf(mode) {
        return mode === "region" ? "crop_free"
             : mode === "window" ? "select_window" : "fullscreen"
    }

    Repeater {
        model: ["region", "window", "full"]

        delegate: VitrailButton {
            required property string modelData

            Layout.fillWidth: true
            variant: "text"
            size: root.size
            icon: root.iconOf(modelData)
            onClicked: root.shotRequested(modelData)
        }
    }

    VitrailButton {
        Layout.fillWidth: true
        variant: "text"
        size: root.size
        tone: root.recording ? "error" : "secondary"
        icon: root.recording ? "stop_circle" : "screen_record"
        onClicked: root.recordRequested()
    }
}
