import QtQuick
import QtQuick.Layouts
import "../kit/composed"

// The custom colour: the kit's colour picker (wheel, tone slider and hex code)
// in a dialog; the swatch it makes joins the colour row. `start` is where it
// opens from (the colour in use).
EditorDialog {
    id: root

    property var t: function (key) {
        return key
    }
    property string start: ""

    signal chosen(string hex)

    title: root.t("capture.editor.custom")
    accept: root.t("capture.editor.custom.use")
    cancel: root.t("capture.editor.cancel")
    acceptable: picker.valid

    function show() {
        picker.adopt(root.start)
        root.open = true
        picker.focusCode()
    }

    onAccepted: {
        root.open = false
        root.chosen(picker.hex)
    }
    onRejected: root.open = false

    VitrailColorPicker {
        id: picker

        Layout.fillWidth: true
        size: "sm"
        placeholder: root.t("capture.editor.hex")
        onEscaped: root.rejected()
    }
}
