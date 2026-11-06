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

    Component {
        id: tabbedComponent

        VitrailPicker {
            width: 320
            label: "Packs"
            current: "a"
            currentTab: "normal"
            tabs: [
                { key: "normal", label: "Normal" },
                { key: "adaptive", label: "Adaptive" }
            ]
            options: [
                { key: "a", label: "Alpha", tab: "normal" },
                { key: "b", label: "Beta", tab: "normal" },
                { key: "c", label: "Vitrail · Alpha", tab: "adaptive" }
            ]
        }
    }

    Component {
        id: glyphComponent

        VitrailPicker {
            width: 320
            label: "Packs"
            current: "a"
            options: [{ key: "a", label: "Alpha", glyph: "block" }]
        }
    }

    Component {
        id: largeComponent

        VitrailPicker {
            width: 220
            large: true
            cellPreview: 120
            cellColumns: 4
            label: "Packs"
            current: "a"
            options: [
                { key: "a", label: "Alpha" },
                { key: "b", label: "Beta" }
            ]
        }
    }

    Component {
        id: actionComponent

        VitrailPicker {
            width: 320
            label: "Packs"
            current: "a"
            options: [{ key: "a", label: "Alpha" }]
            actions: [{ key: "delete", label: "Delete pack", confirm: "Confirm delete" }]
        }
    }

    SignalSpy {
        id: selected

        signalName: "selected"
    }

    SignalSpy {
        id: actionSpy

        signalName: "actionTriggered"
    }

    function findText(item, value) {
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.text !== undefined && child.text === value)
                return child
            if (child.children) {
                var found = findText(child, value)
                if (found)
                    return found
            }
        }
        return null
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

    function test_tabs_split_the_rows() {
        var picker = createTemporaryObject(tabbedComponent, testCase)
        compare(picker.matched.length, 2)
        picker.currentTab = "adaptive"
        compare(picker.matched.length, 1)
        compare(picker.matched[0].key, "c")
        picker.currentTab = "normal"
        compare(picker.matched.length, 2)
    }

    function test_a_chosen_glyph_is_not_filled() {
        var picker = createTemporaryObject(glyphComponent, testCase)
        picker.open()
        tryCompare(picker, "expanded", true)
        var glyph = findText(picker, "block")
        verify(glyph !== null)
        // Icons are outlined everywhere: no FILL axis is set at all.
        verify(glyph.font.variableAxes["FILL"] === undefined)
    }

    function test_neither_trigger_draws_a_chevron() {
        var compact = createTemporaryObject(pickerComponent, testCase)
        compare(findText(compact, "expand_more"), null)
        var large = createTemporaryObject(largeComponent, testCase)
        compare(findText(large, "expand_more"), null)
    }

    function test_the_large_trigger_is_a_card_with_the_name() {
        var picker = createTemporaryObject(largeComponent, testCase)
        compare(picker.large, true)
        verify(picker.implicitHeight > picker.boxHeight)
        verify(findText(picker, "Alpha") !== null)
    }

    function test_the_large_trigger_still_opens_the_dialog() {
        var picker = createTemporaryObject(largeComponent, testCase)
        mouseClick(picker, picker.width / 2, picker.height / 2)
        tryCompare(picker, "expanded", true)
    }

    function test_the_dialog_opens_on_the_tab_of_the_chosen_row() {
        var picker = createTemporaryObject(tabbedComponent, testCase)
        picker.current = "c"
        picker.open()
        tryCompare(picker, "expanded", true)
        compare(picker.currentTab, "adaptive")
    }

    function test_deleting_asks_for_a_second_click() {
        var picker = createTemporaryObject(actionComponent, testCase)
        actionSpy.target = picker
        actionSpy.clear()
        picker.open()
        tryCompare(picker, "expanded", true)
        picker.activateAction("delete")
        compare(picker.pendingAction, "delete")
        compare(actionSpy.count, 0)
        picker.activateAction("delete")
        compare(actionSpy.count, 1)
        compare(actionSpy.signalArguments[0][0], "delete")
    }
}
