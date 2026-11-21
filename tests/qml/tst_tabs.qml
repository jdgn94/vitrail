import QtQuick
import QtTest
import "../../kit"

// VitrailTabs: a tab may carry an icon before its label; Left / Right move
// the current tab.
TestCase {
    id: testCase

    name: "VitrailTabs"
    when: windowShown
    visible: true
    width: 500
    height: 200

    VitrailPalette {
        id: palette
    }

    Component {
        id: control

        VitrailTabs {
            width: 500
            current: "a"
            tabs: [
                { key: "a", label: "Alpha", icon: "palette" },
                { key: "b", label: "Beta" },
                { key: "c", label: "Gamma", icon: "layers" }
            ]
        }
    }

    Component {
        id: long

        VitrailTabs {
            width: 260
            current: "a"
            tabs: [
                { key: "a", label: "Frame and panels" },
                { key: "b", label: "Notifications" },
                { key: "c", label: "On-screen display" },
                { key: "d", label: "Widgets" },
                { key: "e", label: "Background" },
                { key: "f", label: "Capture" }
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
        var box = createTemporaryObject(control, testCase)
        verify(box)
        spy.target = box
        spy.clear()
        return box
    }

    function textOf(item, glyph) {
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.children && child.children.length > 0) {
                var found = textOf(child, glyph)
                if (found)
                    return found
            }
            if (child.text !== undefined && (child.font.family === VitrailTokens.iconFamily) === glyph)
                return child
        }
        return null
    }

    function test_icon_is_drawn_before_the_label() {
        var box = make()
        var icon = textOf(box.currentItem, true)
        var label = textOf(box.currentItem, false)
        verify(icon && icon.visible)
        compare(icon.text, "palette")
        verify(icon.x < label.x)
        verify(box.currentItem.width >= icon.width + label.width)
    }

    function test_tab_without_icon_shows_only_the_label() {
        var box = make()
        var second = box.currentItem.parent.children[1]
        verify(!textOf(second, true).visible)
        compare(second.implicitWidth, textOf(second, false).implicitWidth)
    }

    function sameColor(a, b) {
        return a.r === b.r && a.g === b.g && a.b === b.b && a.a === b.a
    }

    function test_current_icon_uses_the_accent_colour_only() {
        var box = make()
        var icon = textOf(box.currentItem, true)
        tryVerify(function () { return sameColor(icon.color, box.accent) })
        // The FILL axis stays 0: the active state is the colour.
        compare(icon.font.variableAxes["FILL"], 0)
        box.current = "c"
        tryVerify(function () {
            var next = textOf(box.currentItem, true)
            return next !== null && sameColor(next.color, box.accent)
        })
        // The old icon fades back to the normal ink.
        tryVerify(function () { return sameColor(icon.color, box.foreground) })
        compare(icon.font.variableAxes["FILL"], 0)
    }

    function test_the_icon_family_follows_the_token() {
        var box = make()
        VitrailTokens.iconVariant = "sharp"
        compare(textOf(box.currentItem, true).font.family, "Material Symbols Sharp")
        VitrailTokens.iconVariant = "rounded"
        compare(textOf(box.currentItem, true).font.family, VitrailTokens.iconFamily)
    }

    function test_keys_move_the_current_tab() {
        var box = make()
        box.forceActiveFocus()
        keyClick(Qt.Key_Right)
        compare(spy.signalArguments[0][0], "b")
        keyClick(Qt.Key_Left)
        compare(spy.signalArguments[1][0], "c")
    }

    function test_is_one_keyboard_stop() {
        verify(make().activeFocusOnTab)
    }

    // A row wider than the control scrolls sideways: the wheel moves it, and a
    // tab chosen out of sight is brought into view.
    function test_a_long_row_scrolls_with_the_wheel() {
        var box = createTemporaryObject(long, testCase)
        verify(box)
        verify(box.contentWidth > box.width)
        compare(box.contentX, 0)
        mouseWheel(box, box.width / 2, box.height / 2, 0, -120)
        // The move is animated, so it lands a moment later.
        tryVerify(function () { return box.contentX > 0 })
    }

    // Dragging the row moves it and selects nothing.
    function test_a_long_row_scrolls_by_dragging() {
        var box = createTemporaryObject(long, testCase)
        verify(box)
        spy.target = box
        spy.clear()
        mouseDrag(box, box.width * 0.7, box.height / 2, -140, 0)
        tryVerify(function () { return box.contentX > 0 })
        compare(spy.count, 0)
    }

    function test_the_current_tab_is_scrolled_into_view() {
        var box = createTemporaryObject(long, testCase)
        verify(box)
        box.current = "f"
        tryVerify(function () {
            return box.currentItem !== null
                   && box.currentItem.x + box.currentItem.width <= box.contentX + box.width
                   && box.currentItem.x >= box.contentX
        })
    }

    // A tab set before the row was laid out must not scroll the row past its
    // own first tab (the pill would start half cut).
    function test_choosing_a_tab_before_the_first_layout_does_not_scroll_past_it() {
        var box = createTemporaryObject(long, testCase, { width: 0 })
        verify(box)
        box.current = "b"
        box.current = "a"
        wait(50)
        box.width = 260
        tryVerify(function () { return box.contentX === 0 })
    }

    // A row scrolled while the control was narrow returns to its start once
    // the whole row fits again (the settings window lays it out small first).
    function test_a_row_that_then_fits_returns_to_the_start() {
        var box = createTemporaryObject(long, testCase, { width: 120 })
        verify(box)
        box.current = "f"
        tryVerify(function () { return box.contentX > 0 })
        box.width = 900
        tryVerify(function () { return box.contentX === 0 })
    }

    function test_a_row_that_fits_does_not_scroll() {
        var box = make()
        compare(box.contentWidth, box.width)
        compare(box.contentX, 0)
    }

    function test_click_selects() {
        var box = make()
        // The empty space after the tabs selects nothing.
        mouseClick(box, box.width - 2, box.height / 2)
        compare(spy.count, 0)
        var first = findChild(box, "tab0")
        verify(first !== null)
        mouseClick(first, first.width / 2, first.height / 2)
        compare(spy.signalArguments[0][0], "a")
    }
}
