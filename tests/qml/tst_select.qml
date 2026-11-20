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

    function menu(box) {
        var popup = findChild(box, "popup")
        verify(popup)
        tryVerify(function () { return popup.visible && popup.implicitHeight > 0 })
        return popup
    }

    function test_the_menu_births_on_the_field() {
        var box = make()
        box.y = 150
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        var list = findChild(testCase.Window.contentItem, "options")
        var row = list.rowHeight
        compare(popup.y, box.height / 2 - (popup.topPadding + box.currentIndex * row + row / 2))
        verify(box.y + popup.y > 0, "the popup starts inside the window")
    }

    function test_the_menu_widens_to_its_longest_option() {
        var box = make()
        box.width = 160
        box.y = 150
        box.options = [
            { key: "a", label: "an extremely long wallpaper file name.webp" },
            { key: "b", label: "short.webp" }
        ]
        box.current = "a"
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        verify(popup.width > box.width, "the long option is not cut")
        verify(popup.width <= testCase.width, "the menu never leaves the window")
    }

    function test_the_menu_stays_inside_the_window() {
        var box = make()
        box.y = testCase.height - box.height - 10
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        verify(box.y + popup.y >= 0)
        verify(box.y + popup.y + popup.height <= testCase.height)
    }

    function test_a_wide_box_keeps_its_menu_on_screen() {
        var box = make()
        box.x = testCase.width - 150
        box.y = 150
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        verify(box.x + popup.x >= 0)
        verify(box.x + popup.x + popup.width <= testCase.width)
    }

    function test_a_long_list_keeps_the_current_option_on_the_field() {
        var box = make()
        box.y = 150
        var list = findChild(testCase.Window.contentItem, "options")
        var options = []
        for (var i = 0; i < 20; i++)
            options.push({ key: String(i), label: "Mode " + i })
        box.options = options
        box.current = "15"
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        var row = list.itemAtIndex(15)
        verify(row)
        var centre = popup.y + popup.topPadding + row.y - list.contentY + row.height / 2
        verify(Math.abs(centre - box.height / 2) <= 2, "the current row sits on the field (got " + centre + ")")
        keyClick(Qt.Key_Escape)
        tryCompare(box, "expanded", false)
        box.current = "4"
        keyClick(Qt.Key_Down)
        tryVerify(function () { return popup.visible })
        tryVerify(function () { return list.itemAtIndex(4) !== null })
        row = list.itemAtIndex(4)
        centre = popup.y + popup.topPadding + row.y - list.contentY + row.height / 2
        verify(Math.abs(centre - box.height / 2) <= 2,
               "after picking another value it is still on the field (got " + centre + ")")
    }

    function test_a_menu_clamped_by_the_window_still_puts_the_current_row_on_the_field() {
        var box = make()
        box.y = testCase.height - box.height - 6
        var list = findChild(testCase.Window.contentItem, "options")
        var options = []
        for (var i = 0; i < 20; i++)
            options.push({ key: String(i), label: "Mode " + i })
        box.options = options
        box.current = "15"
        keyClick(Qt.Key_Down)
        var popup = menu(box)
        tryVerify(function () { return list.itemAtIndex(15) !== null })
        var row = list.itemAtIndex(15)
        var centre = popup.y + popup.topPadding + row.y - list.contentY + row.height / 2
        verify(Math.abs(centre - box.height / 2) <= 2,
               "the current row still sits on the field (got " + centre + ")")
        verify(box.y + popup.y >= 0, "the menu stays on screen")
        verify(box.y + popup.y + popup.height <= testCase.height, "the menu stays on screen")
    }
}
