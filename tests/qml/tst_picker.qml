import QtQuick
import QtTest
import "../../kit"

// The picker: the trigger shows the chosen option, the dialog lists them all
// and picking one reports its key.
TestCase {
    id: testCase

    name: "Picker"
    when: windowShown
    visible: true
    width: 900
    height: 700

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    Component {
        id: pickerComponent

        VitrailPicker {
            width: 320
            label: "Icon theme"
            current: "b"
            options: [
                { key: "a", label: "Alpha" },
                { key: "b", label: "Beta" },
                { key: "c", label: "Gamma", family: "DejaVu Sans" }
            ]
        }
    }

    SignalSpy {
        id: selected

        signalName: "selected"
    }

    function test_it_shows_the_chosen_option() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        verify(picker !== null)
        compare(picker.currentLabel, "Beta")
    }

    function test_it_opens_on_the_chosen_row() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        picker.open()
        tryCompare(picker, "expanded", true)
        compare(picker.highlighted, 1)
        picker.close()
        tryCompare(picker, "expanded", false)
    }

    function test_picking_reports_the_key_and_closes() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        selected.target = picker
        selected.clear()
        picker.open()
        tryCompare(picker, "expanded", true)
        picker.pick(2)
        compare(selected.count, 1)
        compare(selected.signalArguments[0][0], "c")
        tryCompare(picker, "expanded", false)
    }

    function test_the_search_field_narrows_the_rows() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        picker.filter = "ga"
        compare(picker.matched.length, 1)
        compare(picker.matched[0].key, "c")
        picker.filter = ""
        compare(picker.matched.length, 3)
    }

    function test_picking_after_a_search_uses_the_narrowed_row() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        selected.target = picker
        selected.clear()
        picker.filter = "alp"
        picker.pick(0)
        compare(selected.count, 1)
        compare(selected.signalArguments[0][0], "a")
    }

    function test_an_empty_list_does_not_open() {
        var picker = createTemporaryObject(pickerComponent, testCase)
        picker.options = []
        picker.open()
        compare(picker.expanded, false)
        compare(picker.currentLabel, "b")
    }
}
