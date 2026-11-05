import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "notes.js" as Notes

// Quick notes: a line to capture, and the last few, newest first. The text
// belongs to the shell (a preference); this only reports what was typed and
// what was removed.
ColumnLayout {
    id: root

    property var strings: ({})
    // The stored text: one note per line, newest first.
    property string text: ""
    // How many notes the panel lists.
    property int visibleCount: 3
    // sm / md / lg: "md" keeps the panel's compact field and buttons; "lg"
    // gives them the next size up.
    property string size: "md"

    signal noteAdded(string note)
    signal noteRemoved(int index)

    spacing: VitrailTokens.gap("xs")


    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailField {
        id: field

        Layout.fillWidth: true
        size: root.size === "lg" ? "md" : "sm"
        leadingIcon: "edit_note"
        placeholder: root.t("notes.placeholder")
        onAccepted: {
            root.noteAdded(field.text)
            field.text = ""
        }
    }

    Repeater {
        model: Notes.shown(root.text, root.visibleCount)

        delegate: RowLayout {
            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")


            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                elide: Text.ElideRight
                text: modelData
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                size: root.size === "lg" ? "md" : "sm"
                icon: "close"
                onClicked: root.noteRemoved(index)
            }
        }
    }
}
