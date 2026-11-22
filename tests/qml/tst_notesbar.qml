import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/notes"
import "../../bar/notes/notes.js" as Notes
import "../../bar/notes/notesbar.js" as NotesBar

// The notes bar element: how many notes the button counts, the capped list its
// popup shows, the first line and the age of each note, and the field that
// adds through the one store in notes.js.
TestCase {
    id: testCase

    name: "NotesBar"
    when: windowShown
    visible: true
    width: 440
    height: 560

    readonly property var strings: ({
        "bar.widget.notes": "Notes",
        "bar.notes.empty": "No notes yet",
        "bar.notes.tooltip.one": "1 note",
        "bar.notes.tooltip": "%1 notes",
        "bar.notes.age.now": "just now",
        "bar.notes.age.minutes": "%1 min ago",
        "bar.notes.age.hours": "%1 h ago",
        "bar.notes.age.days": "%1 d ago",
        "notes.placeholder": "Quick note"
    })

    readonly property string notes: '["first\\nsecond",{"text":"newest","at":196400000},"older"]'

    Component {
        id: buttonComponent

        NotesButton {
            width: 80
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        NotesPanel {
            width: 360
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: added; signalName: "noteAdded" }
    SignalSpy { id: opened; signalName: "noteOpenRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    function descendants(item, name, found) {
        var out = found || []
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.objectName === name)
                out.push(child)
            descendants(child, name, out)
        }
        return out
    }

    function test_the_count_is_the_number_of_notes() {
        compare(NotesBar.count(""), 0)
        compare(NotesBar.count('["a","b"]'), 2)
        compare(NotesBar.count(notes), 3)
        compare(NotesBar.count("not json"), 0)
    }

    function test_the_cap_defaults_to_five_and_stays_inside_the_store_limit() {
        compare(NotesBar.cap(undefined), 5)
        compare(NotesBar.cap(0), 1)
        compare(NotesBar.cap(3), 3)
        compare(NotesBar.cap(Notes.LIMIT + 10), Notes.LIMIT)
        compare(NotesBar.shown(notes, 2).length, 2)
        compare(NotesBar.shown(notes, 1)[0].text, "first\nsecond")
        compare(NotesBar.shown("", 5), [])
    }

    function test_the_title_is_the_first_line_and_the_age_is_relative() {
        compare(NotesBar.title("first\nsecond"), "first")
        compare(NotesBar.title("  only  "), "only")
        compare(NotesBar.ageText(0, 200000000, testCase.strings), "")
        compare(NotesBar.ageText(200000000 - 1000, 200000000, testCase.strings), "just now")
        compare(NotesBar.ageText(200000000 - 180000, 200000000, testCase.strings), "3 min ago")
        compare(NotesBar.ageText(200000000 - 3600000, 200000000, testCase.strings), "1 h ago")
        compare(NotesBar.ageText(200000000 - 172800000, 200000000, testCase.strings), "2 d ago")
    }

    function test_a_note_added_with_a_time_keeps_its_age_in_the_one_store() {
        var text = Notes.add('["old"]', "new", 5000)
        compare(Notes.parse(text), ["new", "old"])
        compare(Notes.entries(text)[0].at, 5000)
        text = Notes.add(text, "later", 9000)
        compare(Notes.entries(text)[0].at, 9000)
        compare(Notes.entries(text)[1].at, 5000)
    }

    function test_the_button_shows_the_count_and_the_first_note() {
        var button = make(buttonComponent)
        compare(button.active, false)
        compare(button.text, "")
        compare(button.tooltip, "No notes yet")
        button.notes = notes
        compare(button.count, 3)
        compare(button.active, true)
        compare(button.text, "3")
        compare(button.tooltip, "3 notes")
        compare(button.tooltipDetail, "first")
    }

    function test_the_popup_lists_only_its_cap_of_notes() {
        var panel = createTemporaryObject(panelComponent, testCase, {
            notes: notes, maxNotes: 2, now: 200000000
        })
        verify(panel !== null)
        compare(panel.shown.length, 2)
        compare(descendants(panel, "notesRow").length, 2)
        var age = findChild(panel, "notesAge1")
        verify(age !== null)
        compare(age.text, "1 h ago")
    }

    function test_the_field_adds_a_note_and_a_row_opens_the_card() {
        var panel = createTemporaryObject(panelComponent, testCase, {
            notes: notes, maxNotes: 3, now: 200000000
        })
        added.target = panel
        opened.target = panel
        added.clear()
        opened.clear()

        var field = findChild(panel, "quickNoteField")
        verify(field !== null)
        field.forceActiveFocus()
        field.text = "a fresh note"
        field.accepted()
        compare(added.count, 1)
        compare(added.signalArguments[0][0], "a fresh note")

        var open = findChild(panel, "notesOpen0")
        verify(open !== null)
        mouseClick(open, open.width / 2, open.height / 2)
        compare(opened.count, 1)
    }
}
