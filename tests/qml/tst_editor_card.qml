import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/capture"

// The editor's card driven the way the user does: the pointer draws, the keys
// pick tools and undo, a label is typed in place and leaving asks first when
// there is something to lose.
TestCase {
    id: testCase

    name: "EditorCard"
    when: windowShown
    visible: true
    width: 1000
    height: 700

    VitrailPalette {
        id: palette
    }

    Component {
        id: cardComponent

        EditorCard {
            width: 900
            height: 600
            imageWidth: 400
            imageHeight: 300
            t: function (key) { return key }
            screenSize: ({ w: 1920, h: 1080 })
        }
    }

    Component {
        id: colourComponent

        EditorColorDialog {
            width: 600
            height: 500
            start: "#f44336"
        }
    }

    SignalSpy {
        id: discarded

        signalName: "discarded"
    }

    SignalSpy {
        id: chosen

        signalName: "chosen"
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(properties) {
        var card = createTemporaryObject(cardComponent, testCase, properties || ({}))
        verify(card)
        card.forceActiveFocus()
        return card
    }

    function drag(card, from, to) {
        var start = card.view.viewPoint(from)
        var end = card.view.viewPoint(to)
        mousePress(card.view, start.x, start.y)
        mouseMove(card.view, (start.x + end.x) / 2, (start.y + end.y) / 2)
        mouseMove(card.view, end.x, end.y)
        mouseRelease(card.view, end.x, end.y)
    }

    function click(card, at) {
        var point = card.view.viewPoint(at)
        mouseClick(card.view, point.x, point.y)
    }

    function test_the_pencil_makes_one_element_per_stroke() {
        var card = make()
        compare(card.tool, "pencil")
        drag(card, { x: 50, y: 50 }, { x: 150, y: 120 })
        compare(card.count, 1)
        compare(card.history.done[0].type, "pen")
        verify(card.history.done[0].points.length >= 2)
        drag(card, { x: 60, y: 200 }, { x: 160, y: 220 })
        compare(card.count, 2)
    }

    function test_a_shape_is_dragged_and_a_click_makes_none() {
        var card = make()
        card.selectTool("shape")
        drag(card, { x: 40, y: 40 }, { x: 140, y: 100 })
        compare(card.count, 1)
        var shape = card.history.done[0]
        compare(shape.type, "rect")
        compare([Math.round(shape.x), Math.round(shape.y), Math.round(shape.w), Math.round(shape.h)], [40, 40, 100, 60])
        click(card, { x: 200, y: 200 })
        compare(card.count, 1)
    }

    function test_an_arrow_follows_the_drag_and_the_options() {
        var card = make()
        card.selectTool("arrow")
        card.setOption("arrow", "heads", "both")
        drag(card, { x: 20, y: 20 }, { x: 220, y: 20 })
        compare(card.count, 1)
        compare(card.history.done[0].type, "arrow")
        compare(card.history.done[0].both, true)
    }

    function test_drawing_outside_the_picture_stays_inside_it() {
        var card = make()
        card.selectTool("shape")
        var start = card.view.viewPoint({ x: 300, y: 200 })
        mousePress(card.view, start.x, start.y)
        mouseMove(card.view, start.x + 600, start.y + 600)
        mouseRelease(card.view, start.x + 600, start.y + 600)
        var shape = card.history.done[0]
        compare(shape.x + shape.w, 400)
        compare(shape.y + shape.h, 300)
    }

    function test_undo_and_redo_by_key_and_button_state() {
        var card = make()
        drag(card, { x: 50, y: 50 }, { x: 150, y: 120 })
        keyClick(Qt.Key_Z, Qt.ControlModifier)
        compare(card.count, 0)
        verify(card.history.undone.length === 1)
        keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
        compare(card.count, 1)
        keyClick(Qt.Key_Z, Qt.ControlModifier)
        keyClick(Qt.Key_Y, Qt.ControlModifier)
        compare(card.count, 1)
    }

    function test_the_tool_keys_pick_the_tool() {
        var card = make()
        keyClick(Qt.Key_T)
        compare(card.tool, "text")
        keyClick(Qt.Key_F)
        compare(card.tool, "shape")
        keyClick(Qt.Key_A)
        compare(card.tool, "arrow")
        keyClick(Qt.Key_P)
        compare(card.tool, "pencil")
    }

    function test_a_label_is_typed_in_place_and_enter_confirms() {
        var card = make()
        card.selectTool("text")
        click(card, { x: 80, y: 80 })
        verify(card.view.editing)
        keyClick("h")
        keyClick("i")
        keyClick(Qt.Key_Return)
        verify(!card.view.editing)
        compare(card.count, 1)
        compare(card.history.done[0].type, "text")
        compare(card.history.done[0].text, "hi")
        compare(card.history.done[0].x, 80)
    }

    function test_escape_cancels_a_label_and_an_empty_one_is_dropped() {
        var card = make()
        card.selectTool("text")
        click(card, { x: 80, y: 80 })
        keyClick("x")
        keyClick(Qt.Key_Escape)
        verify(!card.view.editing)
        compare(card.count, 0)
        click(card, { x: 80, y: 80 })
        keyClick(Qt.Key_Return)
        compare(card.count, 0)
    }

    function test_a_click_elsewhere_confirms_the_label_without_placing_another() {
        var card = make()
        card.selectTool("text")
        click(card, { x: 80, y: 80 })
        keyClick("a")
        click(card, { x: 250, y: 200 })
        compare(card.count, 1)
        verify(!card.view.editing)
    }

    function test_letters_typed_in_a_label_do_not_pick_tools() {
        var card = make()
        card.selectTool("text")
        click(card, { x: 80, y: 80 })
        keyClick("p")
        keyClick("a")
        compare(card.tool, "text")
        keyClick(Qt.Key_Return)
        compare(card.history.done[0].text, "pa")
    }

    function test_leaving_with_nothing_drawn_closes_at_once() {
        var card = make()
        discarded.target = card
        discarded.clear()
        keyClick(Qt.Key_Escape)
        compare(discarded.count, 1)
    }

    function test_leaving_with_work_asks_first_and_counts_it() {
        var card = make()
        discarded.target = card
        discarded.clear()
        drag(card, { x: 50, y: 50 }, { x: 150, y: 120 })
        drag(card, { x: 60, y: 200 }, { x: 160, y: 220 })
        keyClick(Qt.Key_Escape)
        compare(discarded.count, 0)
        verify(card.dialogOpen)
        keyClick(Qt.Key_Escape)
        verify(!card.dialogOpen)
        compare(card.count, 2)
        compare(discarded.count, 0)
        keyClick(Qt.Key_Escape)
        verify(card.dialogOpen)
        keyClick(Qt.Key_Return)
        compare(discarded.count, 1)
    }

    function typeCode(text) {
        keyClick("a", Qt.ControlModifier)
        for (var i = 0; i < text.length; i++)
            keyClick(text[i])
    }

    function test_the_custom_colour_is_typed_and_used_with_enter() {
        var dialog = createTemporaryObject(colourComponent, testCase)
        chosen.target = dialog
        chosen.clear()
        dialog.show()
        verify(dialog.open)
        typeCode("00ff00")
        keyClick(Qt.Key_Return)
        compare(chosen.count, 1)
        compare(chosen.signalArguments[0][0], "#00ff00")
        verify(!dialog.open)
    }

    function test_a_code_that_is_not_a_colour_cannot_be_used() {
        var dialog = createTemporaryObject(colourComponent, testCase)
        chosen.target = dialog
        chosen.clear()
        dialog.show()
        typeCode("12")
        verify(!dialog.acceptable)
        keyClick(Qt.Key_Return)
        compare(chosen.count, 0)
        verify(dialog.open)
    }

    function test_the_custom_colour_opens_on_the_colour_in_use_every_time() {
        var dialog = createTemporaryObject(colourComponent, testCase)
        chosen.target = dialog
        chosen.clear()
        dialog.show()
        typeCode("00ff00")
        keyClick(Qt.Key_Escape)
        verify(!dialog.open)
        dialog.show()
        keyClick(Qt.Key_Return)
        compare(chosen.signalArguments[0][0], "#f44336")
    }

    function test_the_options_to_remember_are_the_ones_in_use() {
        var card = make()
        card.selectTool("arrow")
        card.setOption("arrow", "line", "dashed")
        card.useCustom("#123456")
        var again = make({ saved: card.snapshot(), tool: "arrow" })
        compare(again.opts.arrow.line, "dashed")
        compare(again.opts.arrow.color, "#123456")
        compare(again.opts.custom, "#123456")
        compare(again.tool, "arrow")
    }

    function test_a_saved_tool_that_does_not_exist_is_the_pencil() {
        compare(make({ tool: "lasso" }).tool, "pencil")
    }

    function test_the_window_is_sized_from_the_picture() {
        var small = make()
        compare(small.implicitWidth, VitrailTokens.capture.editor.window.width)
        var big = make({ imageWidth: 1400, imageHeight: 800 })
        verify(big.implicitWidth > small.implicitWidth)
        verify(big.implicitHeight > small.implicitHeight)
        verify(big.implicitWidth <= 1920 * VitrailTokens.capture.editor.window.share)
    }

    function test_zoom_changes_the_label_not_the_picture() {
        var card = make()
        var fit = card.view.viewScale
        card.zoomBy(1)
        verify(card.view.viewScale > fit)
        card.zoomBy(-1)
        compare(card.view.viewScale, fit)
        keyClick(Qt.Key_Minus, Qt.ControlModifier)
        verify(card.view.viewScale < fit)
        keyClick(Qt.Key_0, Qt.ControlModifier)
        compare(card.view.viewScale, fit)
        compare(card.count, 0)
    }
}
