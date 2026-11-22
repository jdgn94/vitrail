import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "notesbar.js" as NotesBar

// The notes element's popup: the newest notes with their first line and age, a
// click that opens the full notes card in the notification panel, and the same
// field the panel uses to write a new one (QuickNotes → notes.js, one store).
// The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    // The stored text: one JSON array, newest first (shell.notes).
    property string notes: ""
    // The `notesPopupMax` preference: how many notes the list keeps.
    property int maxNotes: 5
    // "now" for the ages; the shell passes Date.now().
    property real now: Date.now()

    signal settingsRequested()
    signal noteAdded(string note)
    signal noteOpenRequested()

    readonly property int count: NotesBar.count(root.notes)
    readonly property var shown: NotesBar.shown(root.notes, root.maxNotes)

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    implicitWidth: 360
    implicitHeight: body.implicitHeight

    // The ages stay honest while the popup is open.
    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
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
                text: root.t("bar.widget.notes")
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        QuickNotes {
            Layout.fillWidth: true
            strings: root.strings
            text: root.notes
            visibleCount: root.maxNotes
            size: "md"
            style: "minimal"
            onNoteAdded: function (note) { root.noteAdded(note) }
        }

        VitrailText {
            objectName: "notesEmpty"

            Layout.fillWidth: true
            visible: root.count === 0
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.t("bar.notes.empty")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("xs")

            Repeater {
                model: root.shown

                delegate: RowLayout {
                    id: row

                    required property var modelData
                    required property int index

                    objectName: "notesRow"

                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("xs")

                    VitrailButton {
                        objectName: "notesOpen" + row.index

                        Layout.fillWidth: true
                        variant: "text"
                        icon: "edit_note"
                        text: NotesBar.title(row.modelData.text)
                        onClicked: root.noteOpenRequested()
                    }

                    VitrailText {
                        objectName: "notesAge" + row.index

                        variant: "label"
                        opacity: 0.7
                        text: NotesBar.ageText(row.modelData.at, root.now, root.strings)
                    }
                }
            }
        }
    }
}
