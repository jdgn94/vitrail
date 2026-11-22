import QtQuick
import ".."
import "notesbar.js" as NotesBar

// The notes bar element: a note glyph and how many notes there are, from the
// same `quickNotes` preference the notification panel writes (bar/notes). The
// tooltip's second line is the newest note's first line. With no note the
// element is not active, so "only while active" leaves the bar empty.
BarElementBase {
    id: root

    // The stored text: one JSON array, newest first (shell.notes).
    property string notes: ""

    readonly property int count: NotesBar.count(root.notes)
    readonly property var first: NotesBar.shown(root.notes, 1)

    icon: "edit_note"
    text: root.count > 0 ? String(root.count) : ""
    active: root.count > 0
    tooltip: root.count === 0 ? root.t("bar.notes.empty")
             : root.count === 1 ? root.t("bar.notes.tooltip.one")
                                : root.t("bar.notes.tooltip").replace("%1", root.count)
    tooltipDetail: root.first.length > 0 ? NotesBar.title(root.first[0].text)
                                         : root.t("bar.notes.empty")
}
