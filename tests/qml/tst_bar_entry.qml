import QtQuick
import QtQuick.Layouts
import QtTest
import "../../bar"

// BarEntry: the loader every bar element goes through. An element that hides
// itself, has nothing to draw or is switched off contributes no size and no
// spacing to the bar's grid.
TestCase {
    id: testCase

    name: "BarEntry"
    when: windowShown
    visible: true
    width: 400
    height: 100

    Component {
        id: visibleContent

        Item {
            implicitWidth: 40
            implicitHeight: 24
        }
    }

    Component {
        id: hiddenContent

        Item {
            property bool shown: false
            implicitWidth: 40
            implicitHeight: 24
        }
    }

    Component {
        id: emptyContent

        Item {
            implicitWidth: 0
            implicitHeight: 0
        }
    }

    Component {
        id: noHeightContent

        Item {
            implicitWidth: 40
            implicitHeight: 0
        }
    }

    Component {
        id: entryComponent

        BarEntry {
        }
    }

    Component {
        id: rowComponent

        RowLayout {
            spacing: 12
            property alias hiddenEntry: first
            property alias shownEntry: second

            BarEntry {
                id: first

                sourceComponent: hiddenContent
            }

            BarEntry {
                id: second

                sourceComponent: visibleContent
            }
        }
    }

    function make(source, properties) {
        var entry = createTemporaryObject(entryComponent, testCase, properties || {})
        verify(entry)
        entry.sourceComponent = source
        tryVerify(function () { return entry.item !== null })
        return entry
    }

    function test_a_visible_entry_keeps_its_size() {
        var entry = make(visibleContent)
        compare(entry.shown, true)
        compare(entry.visible, true)
        compare(entry.Layout.preferredWidth, 40)
        compare(entry.Layout.preferredHeight, 24)
    }

    function test_an_entry_that_hides_itself_contributes_no_size() {
        var entry = make(hiddenContent)
        compare(entry.shown, false)
        compare(entry.visible, false)
        compare(entry.Layout.preferredWidth, 0)
        compare(entry.Layout.preferredHeight, 0)
    }

    function test_an_absent_entry_contributes_no_size() {
        var entry = createTemporaryObject(entryComponent, testCase)
        verify(entry)
        compare(entry.shown, false)
        compare(entry.visible, false)
        compare(entry.Layout.preferredWidth, 0)
        compare(entry.Layout.preferredHeight, 0)
    }

    function test_an_empty_entry_contributes_no_size() {
        var entry = make(emptyContent)
        compare(entry.shown, false)
        compare(entry.visible, false)
        compare(entry.Layout.preferredWidth, 0)
        compare(entry.Layout.preferredHeight, 0)
    }

    function test_a_switched_off_entry_contributes_no_size() {
        var entry = make(visibleContent, { contentVisible: false })
        compare(entry.shown, false)
        compare(entry.visible, false)
        compare(entry.Layout.preferredWidth, 0)
        compare(entry.Layout.preferredHeight, 0)
    }

    function test_a_vertical_entry_collapses_on_its_height() {
        var entry = make(noHeightContent, { vertical: true })
        compare(entry.shown, false)
        compare(entry.visible, false)
        compare(entry.Layout.preferredWidth, 0)
        compare(entry.Layout.preferredHeight, 0)
    }

    function test_an_entry_appears_when_its_content_does() {
        var entry = make(hiddenContent)
        compare(entry.shown, false)
        entry.item.shown = true
        tryCompare(entry, "shown", true)
        compare(entry.visible, true)
        compare(entry.item.visible, true)
        compare(entry.Layout.preferredWidth, 40)
        compare(entry.Layout.preferredHeight, 24)
    }

    function test_an_entry_appears_when_the_shell_switches_it_on() {
        var entry = make(visibleContent, { contentVisible: false })
        compare(entry.shown, false)
        entry.contentVisible = true
        tryCompare(entry, "shown", true)
        compare(entry.visible, true)
        compare(entry.Layout.preferredWidth, 40)
    }

    function test_a_hidden_entry_takes_no_spacing_beside_a_shown_one() {
        var row = createTemporaryObject(rowComponent, testCase)
        verify(row)
        tryVerify(function () {
            return row.hiddenEntry.item !== null && row.shownEntry.item !== null
        })
        wait(0)
        compare(row.implicitWidth, 40)
        compare(row.shownEntry.x, 0)
    }
}
