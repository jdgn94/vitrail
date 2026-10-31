import QtQuick
import QtTest
import "../../kit"

// VitrailSelect: opens, moves with the keys, picks, closes, jumps by typing.
TestCase {
    id: testCase

    name: "VitrailSelect"
    when: windowShown
    visible: true
    width: 400
    height: 400

    VitrailPalette {
        id: palette
    }

    Component {
        id: select

        VitrailSelect {
            width: 300
            y: 20
            label: "Change every"
            current: "5"
            options: [
                { key: "1", label: "1 min", icon: "timer" },
                { key: "5", label: "5 min" },
                { key: "60", label: "1 h" },
                { key: "1440", label: "24 h" }
            ]
        }
    }

    SignalSpy {
        id: spy

        signalName: "selected"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make() {
        var box = createTemporaryObject(select, testCase)
        verify(box)
        spy.target = box
        spy.clear()
        box.forceActiveFocus()
        tryVerify(function () { return box.activeFocus })
        return box
    }

    function test_shows_the_current_label() {
        var box = make()
        compare(box.currentLabel, "5 min")
        compare(box.currentIndex, 1)
        compare(box.expanded, false)
    }

    function test_down_opens_and_highlights_the_current_option() {
        var box = make()
        keyClick(Qt.Key_Down)
        compare(box.expanded, true)
        compare(box.highlighted, 1)
    }

    function test_keys_move_pick_and_close() {
        var box = make()
        keyClick(Qt.Key_Down)
        keyClick(Qt.Key_Down)
        compare(box.highlighted, 2)
        keyClick(Qt.Key_Down)
        keyClick(Qt.Key_Down)
        compare(box.highlighted, 3, "stops at the last option")
        keyClick(Qt.Key_Up)
        keyClick(Qt.Key_Return)
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "60")
        compare(box.expanded, false)
    }

    function test_escape_closes_without_picking() {
        var box = make()
        keyClick(Qt.Key_Space)
        compare(box.expanded, true)
        keyClick(Qt.Key_Escape)
        compare(box.expanded, false)
        compare(spy.count, 0)
    }

    function test_home_and_end_jump_to_the_ends() {
        var box = make()
        keyClick(Qt.Key_Return)
        keyClick(Qt.Key_End)
        compare(box.highlighted, 3)
        keyClick(Qt.Key_Home)
        compare(box.highlighted, 0)
    }

    function test_typing_jumps_to_the_matching_option() {
        var box = make()
        keyClick(Qt.Key_Down)
        keyClick("2")
        keyClick("4")
        compare(box.highlighted, 3)
        keyClick(Qt.Key_Enter)
        compare(spy.signalArguments[0][0], "1440")
    }

    function test_typing_while_closed_selects() {
        var box = make()
        keyClick("1")
        compare(box.expanded, false)
        compare(spy.signalArguments[0][0], "1")
    }

    function test_the_chevron_turns_when_open() {
        var box = make()
        var chevron = findChild(box, "chevron")
        verify(chevron)
        compare(chevron.rotation, 0)
        keyClick(Qt.Key_Down)
        tryCompare(chevron, "rotation", 180)
        keyClick(Qt.Key_Escape)
        tryCompare(chevron, "rotation", 0)
    }

    function test_clicking_the_box_toggles_the_menu() {
        var box = make()
        mouseClick(box, 100, 20)
        tryCompare(box, "expanded", true)
        mouseClick(box, 100, 20)
        tryCompare(box, "expanded", false)
    }

    function test_clicking_a_row_picks_it() {
        var box = make()
        keyClick(Qt.Key_Down)
        var list = findChild(testCase.Window.contentItem, "options")
        verify(list)
        tryVerify(function () { return list.visible && list.height > 0 })
        var row = list.itemAtIndex(2)
        verify(row)
        var point = row.mapToItem(testCase, row.width / 2, row.height / 2)
        mouseClick(testCase, point.x, point.y)
        tryCompare(spy, "count", 1)
        compare(spy.signalArguments[0][0], "60")
        tryCompare(box, "expanded", false)
    }

    function test_an_unknown_current_shows_an_empty_box() {
        var box = make()
        box.current = "nope"
        compare(box.currentLabel, "")
        compare(box.currentIndex, -1)
    }
}
