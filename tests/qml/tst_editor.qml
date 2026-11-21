import QtQuick
import QtTest
import "../../kit/tokens.js" as Tokens
import "../../bar/capture/editor.js" as Editor

// The screenshot editor's logic: its options and what it remembers, the
// elements it draws, the undo history, the arrow head, the view's scale and
// the keys. No window and no Quickshell: the same functions the editor calls.
TestCase {
    name: "Editor"

    readonly property var tokens: Tokens.capture.editor

    // --- options ---------------------------------------------------------

    function test_the_defaults_come_from_the_tokens() {
        var options = Editor.options(tokens, "")
        compare(options.pencil, { color: "#F44336", width: 4, opacity: 1, mode: "normal" })
        compare(options.text, { color: "#F44336", size: 32, bold: false, background: "none" })
        compare(options.shape, { kind: "rect", color: "#F44336", width: 4, fill: "none" })
        compare(options.arrow, { color: "#F44336", width: 4, heads: "one", line: "solid" })
        compare(options.custom, "")
    }

    function test_saved_options_win_over_the_defaults() {
        var saved = JSON.stringify({ pencil: { color: "#2196F3", width: 12, mode: "highlighter" }, custom: "#112233" })
        var options = Editor.options(tokens, saved)
        compare(options.pencil, { color: "#2196F3", width: 12, opacity: 1, mode: "highlighter" })
        compare(options.custom, "#112233")
        compare(options.arrow.width, 4)
    }

    function test_a_broken_or_hostile_saved_value_keeps_the_defaults() {
        var clean = Editor.options(tokens, "")
        compare(Editor.options(tokens, "not json"), clean)
        compare(Editor.options(tokens, "[1,2]"), clean)
        compare(Editor.options(tokens, JSON.stringify({ pencil: { color: "red", width: "wide", mode: "x" } })), clean)
        compare(Editor.options(tokens, JSON.stringify({ shape: { kind: "star", fill: "x" }, custom: "zzz" })), clean)
    }

    function test_saved_numbers_stay_inside_their_ranges() {
        var options = Editor.options(tokens, JSON.stringify({ pencil: { width: 500, opacity: 0 }, text: { size: 1 } }))
        compare(options.pencil.width, tokens.pen.width.max)
        compare(options.pencil.opacity, tokens.pen.opacity.min)
        compare(options.text.size, tokens.text.size.min)
    }

    function test_the_options_survive_a_round_trip() {
        var options = Editor.options(tokens, "")
        options.arrow.heads = "both"
        options.arrow.line = "dashed"
        options.custom = "#abcdef"
        compare(Editor.options(tokens, Editor.serialize(options)), options)
    }

    function test_an_unknown_tool_is_the_pencil() {
        compare(Editor.toolOf("text"), "text")
        compare(Editor.toolOf("arrow"), "arrow")
        compare(Editor.toolOf("lasso"), "pencil")
        compare(Editor.toolOf(undefined), "pencil")
    }

    // --- colours ---------------------------------------------------------

    function test_text_ink_contrasts_with_the_text_colour() {
        compare(Editor.contrastInk("#FFFFFF", tokens.color.ink), tokens.color.ink.dark)
        compare(Editor.contrastInk("#000000", tokens.color.ink), tokens.color.ink.light)
        compare(Editor.contrastInk("#FFC107", tokens.color.ink), tokens.color.ink.dark)
        compare(Editor.contrastInk("#2196F3", tokens.color.ink), tokens.color.ink.dark)
    }

    // --- elements --------------------------------------------------------

    function test_a_pencil_stroke_keeps_its_options_and_points() {
        var options = Editor.options(tokens, "").pencil
        var stroke = Editor.penElement(tokens, options, [{ x: 1, y: 2 }, { x: 3, y: 4 }])
        compare(stroke.type, "pen")
        compare(stroke.color, "#F44336")
        compare(stroke.width, 4)
        compare(stroke.opacity, 1)
        compare(stroke.points.length, 2)
        compare(stroke.round, true)
    }

    function test_the_highlighter_is_wide_and_translucent() {
        var options = Editor.options(tokens, "").pencil
        options.mode = "highlighter"
        var stroke = Editor.penElement(tokens, options, [{ x: 1, y: 2 }])
        compare(stroke.width, 4 * tokens.pen.highlighter.width)
        compare(stroke.opacity, tokens.pen.highlighter.opacity)
        compare(stroke.round, false)
        options.opacity = 0.2
        compare(Editor.penElement(tokens, options, [{ x: 0, y: 0 }]).opacity, 0.2)
    }

    function test_a_shape_is_the_rectangle_between_two_corners_in_any_direction() {
        var options = Editor.options(tokens, "").shape
        var shape = Editor.shapeElement(tokens, options, { x: 50, y: 40 }, { x: 10, y: 20 })
        compare(shape.type, "rect")
        compare([shape.x, shape.y, shape.w, shape.h], [10, 20, 40, 20])
        options.kind = "ellipse"
        compare(Editor.shapeElement(tokens, options, { x: 0, y: 0 }, { x: 5, y: 5 }).type, "ellipse")
    }

    function test_the_fill_of_a_shape() {
        var options = Editor.options(tokens, "").shape
        compare(Editor.shapeElement(tokens, options, { x: 0, y: 0 }, { x: 9, y: 9 }).fillAlpha, 0)
        options.fill = "solid"
        compare(Editor.shapeElement(tokens, options, { x: 0, y: 0 }, { x: 9, y: 9 }).fillAlpha, 1)
        options.fill = "translucent"
        compare(Editor.shapeElement(tokens, options, { x: 0, y: 0 }, { x: 9, y: 9 }).fillAlpha, tokens.shape.fill)
    }

    function test_an_arrow_head_grows_with_the_line_and_never_gets_too_small() {
        var options = Editor.options(tokens, "").arrow
        options.width = 2
        var thin = Editor.arrowElement(tokens, options, { x: 0, y: 0 }, { x: 100, y: 0 })
        compare(thin.headLength, tokens.arrow.headMin)
        options.width = 20
        var thick = Editor.arrowElement(tokens, options, { x: 0, y: 0 }, { x: 100, y: 0 })
        compare(thick.headLength, 20 * tokens.arrow.head)
        compare(thick.both, false)
        compare(thick.dashed, false)
        options.heads = "both"
        options.line = "dashed"
        var both = Editor.arrowElement(tokens, options, { x: 0, y: 0 }, { x: 100, y: 0 })
        compare(both.both, true)
        compare(both.dashed, true)
    }

    function test_text_takes_the_size_and_a_contrasting_background() {
        var options = Editor.options(tokens, "").text
        options.bold = true
        options.background = "solid"
        options.color = "#FFFFFF"
        var label = Editor.textElement(tokens, options, { x: 7, y: 8 }, "hola")
        compare(label.type, "text")
        compare([label.x, label.y, label.text, label.size, label.bold], [7, 8, "hola", 32, true])
        compare(label.ground, tokens.color.ink.dark)
        compare(label.pad, Math.round(32 * tokens.text.pad))
        options.background = "none"
        compare(Editor.textElement(tokens, options, { x: 0, y: 0 }, "a").ground, "")
    }

    function test_a_click_is_not_a_shape_but_a_drag_is() {
        var options = Editor.options(tokens, "")
        var tiny = Editor.shapeElement(tokens, options.shape, { x: 5, y: 5 }, { x: 6, y: 6 })
        verify(Editor.isEmpty(tiny, tokens))
        var line = Editor.arrowElement(tokens, options.arrow, { x: 5, y: 5 }, { x: 6, y: 6 })
        verify(Editor.isEmpty(line, tokens))
        var real = Editor.shapeElement(tokens, options.shape, { x: 5, y: 5 }, { x: 25, y: 5 })
        verify(!Editor.isEmpty(real, tokens))
        verify(!Editor.isEmpty(Editor.penElement(tokens, options.pencil, [{ x: 1, y: 1 }]), tokens))
        verify(Editor.isEmpty(Editor.textElement(tokens, options.text, { x: 0, y: 0 }, "   "), tokens))
    }

    function test_points_are_clamped_to_the_picture() {
        var image = { w: 100, h: 50 }
        compare(Editor.clampPoint({ x: -5, y: 70 }, image), { x: 0, y: 50 })
        compare(Editor.clampPoint({ x: 30, y: 20 }, image), { x: 30, y: 20 })
    }

    function test_the_pen_ignores_points_closer_than_the_smoothing_distance() {
        var points = [{ x: 0, y: 0 }]
        points = Editor.addPoint(points, { x: 0.5, y: 0 }, 1.5)
        compare(points.length, 1)
        points = Editor.addPoint(points, { x: 3, y: 0 }, 1.5)
        compare(points.length, 2)
    }

    // --- the pen's path --------------------------------------------------

    function test_a_single_point_is_a_dot() {
        compare(Editor.penPath([{ x: 4, y: 5 }]), "M 4 5 L 4.01 5")
    }

    function test_two_points_are_a_line_and_more_are_smoothed() {
        compare(Editor.penPath([{ x: 0, y: 0 }, { x: 10, y: 0 }]), "M 0 0 L 10 0")
        compare(Editor.penPath([{ x: 0, y: 0 }, { x: 10, y: 0 }, { x: 10, y: 10 }]),
                "M 0 0 Q 10 0 10 5 L 10 10")
    }

    // --- the arrow -------------------------------------------------------

    function test_an_arrow_has_a_head_at_its_end_and_the_line_stops_at_its_base() {
        var arrow = { x1: 0, y1: 0, x2: 100, y2: 0, headLength: 20, headAngle: 30, both: false }
        var geometry = Editor.arrowGeometry(arrow)
        compare(geometry.heads.length, 1)
        compare(geometry.heads[0].tip, { x: 100, y: 0 })
        fuzzyCompare(geometry.line.x2, 80, 1e-9)
        compare(geometry.line.x1, 0)
        fuzzyCompare(geometry.heads[0].a.x, 80, 1e-9)
        fuzzyCompare(geometry.heads[0].b.x, 80, 1e-9)
        fuzzyCompare(Math.abs(geometry.heads[0].a.y), 20 * Math.tan(Math.PI / 6), 1e-9)
        fuzzyCompare(geometry.heads[0].a.y, -geometry.heads[0].b.y, 1e-9)
    }

    function test_a_double_arrow_has_two_heads_and_the_line_between_their_bases() {
        var arrow = { x1: 0, y1: 0, x2: 0, y2: 100, headLength: 20, headAngle: 30, both: true }
        var geometry = Editor.arrowGeometry(arrow)
        compare(geometry.heads.length, 2)
        compare(geometry.heads[1].tip, { x: 0, y: 0 })
        fuzzyCompare(geometry.line.y1, 20, 1e-9)
        fuzzyCompare(geometry.line.y2, 80, 1e-9)
    }

    function test_a_short_arrow_shrinks_its_heads_to_fit() {
        var arrow = { x1: 0, y1: 0, x2: 10, y2: 0, headLength: 20, headAngle: 30, both: true }
        var geometry = Editor.arrowGeometry(arrow)
        fuzzyCompare(geometry.line.x1, 5, 1e-9)
        fuzzyCompare(geometry.line.x2, 5, 1e-9)
        var point = Editor.arrowGeometry({ x1: 3, y1: 3, x2: 3, y2: 3, headLength: 20, headAngle: 30, both: false })
        compare(point.heads.length, 0)
    }

    function test_a_head_is_a_closed_triangle_path() {
        var head = { tip: { x: 100, y: 0 }, a: { x: 80, y: -10 }, b: { x: 80, y: 10 } }
        compare(Editor.headPath(head), "M 100 0 L 80 -10 L 80 10 Z")
    }

    // --- history ---------------------------------------------------------

    function test_every_element_is_one_undo_step() {
        var state = Editor.history()
        verify(!Editor.canUndo(state))
        verify(!Editor.canRedo(state))
        state = Editor.commit(state, { type: "pen" })
        state = Editor.commit(state, { type: "rect" })
        compare(state.done.length, 2)
        verify(Editor.canUndo(state))
        state = Editor.undo(state)
        compare(state.done.length, 1)
        compare(state.undone.length, 1)
        verify(Editor.canRedo(state))
        state = Editor.redo(state)
        compare(state.done.map(function (one) { return one.type }), ["pen", "rect"])
        verify(!Editor.canRedo(state))
    }

    function test_a_new_element_forgets_what_was_undone() {
        var state = Editor.commit(Editor.commit(Editor.history(), { type: "a" }), { type: "b" })
        state = Editor.undo(state)
        state = Editor.commit(state, { type: "c" })
        compare(state.undone.length, 0)
        compare(state.done.map(function (one) { return one.type }), ["a", "c"])
    }

    function test_undoing_nothing_changes_nothing() {
        var empty = Editor.history()
        compare(Editor.undo(empty), empty)
        compare(Editor.redo(empty), empty)
    }

    function test_the_history_is_never_modified_in_place() {
        var first = Editor.commit(Editor.history(), { type: "a" })
        Editor.commit(first, { type: "b" })
        Editor.undo(first)
        compare(first.done.length, 1)
        compare(first.undone.length, 0)
    }

    // --- the view --------------------------------------------------------

    function test_the_picture_fits_the_view_and_is_never_enlarged_past_its_pixels() {
        compare(Editor.fitScale({ w: 800, h: 600 }, { w: 1600, h: 1200 }, 1), 0.5)
        compare(Editor.fitScale({ w: 800, h: 300 }, { w: 1600, h: 1200 }, 1), 0.25)
        compare(Editor.fitScale({ w: 800, h: 600 }, { w: 100, h: 100 }, 1), 1)
        // a 2x monitor draws the picture's pixels one to one at half the logical size
        compare(Editor.fitScale({ w: 800, h: 600 }, { w: 100, h: 100 }, 2), 0.5)
    }

    function test_a_view_without_room_still_has_a_scale() {
        verify(Editor.fitScale({ w: 0, h: 0 }, { w: 100, h: 100 }, 1) > 0)
        verify(Editor.fitScale({ w: 100, h: 100 }, { w: 0, h: 0 }, 1) > 0)
    }

    function test_the_zoom_steps_between_its_limits_and_comes_back_to_the_fit() {
        var zoom = tokens.zoom
        compare(Editor.zoomLevel(1, 1, zoom), 1.25)
        compare(Editor.zoomLevel(1, -1, zoom), 0.8)
        compare(Editor.zoomLevel(zoom.max, 1, zoom), zoom.max)
        compare(Editor.zoomLevel(zoom.min, -1, zoom), zoom.min)
        compare(Editor.zoomLevel(0.8, 1, zoom), 1)
        compare(Editor.zoomLevel(1.25, -1, zoom), 1)
    }

    function test_the_percent_counts_the_pictures_own_pixels() {
        compare(Editor.percent(0.5, 1), 50)
        compare(Editor.percent(0.5, 2), 100)
        compare(Editor.percent(1.256, 1), 126)
    }

    function test_the_window_follows_the_picture_between_its_least_and_the_screen() {
        var screen = { w: 1920, h: 1080 }
        var chrome = { w: 24, h: 200 }
        var small = Editor.windowSize({ w: 300, h: 200 }, 1, screen, chrome, tokens.window)
        compare(small, { w: tokens.window.width, h: tokens.window.height })
        var big = Editor.windowSize({ w: 5000, h: 4000 }, 1, screen, chrome, tokens.window)
        compare(big, { w: Math.floor(1920 * tokens.window.share), h: Math.floor(1080 * tokens.window.share) })
        var middle = Editor.windowSize({ w: 1000, h: 500 }, 1, screen, chrome, tokens.window)
        compare(middle, { w: 1024, h: 700 })
        var sharp = Editor.windowSize({ w: 2000, h: 1000 }, 2, screen, chrome, tokens.window)
        compare(sharp, { w: 1024, h: 700 })
    }

    function test_the_view_maps_the_pointer_to_the_picture() {
        compare(Editor.toImage({ x: 50, y: 25 }, 0.5), { x: 100, y: 50 })
        compare(Editor.toImage({ x: 50, y: 25 }, 2), { x: 25, y: 12.5 })
    }

    function test_the_dash_is_the_token_in_line_widths() {
        compare(Editor.dash(tokens, false), [])
        compare(Editor.dash(tokens, true), [3, 2])
    }

    // --- the discard message ---------------------------------------------

    function test_the_discard_message_counts_the_elements() {
        compare(Editor.discardKey(1), "capture.editor.discard.one")
        compare(Editor.discardKey(2), "capture.editor.discard.many")
        compare(Editor.discardKey(40), "capture.editor.discard.many")
    }

    // --- the keys --------------------------------------------------------

    function test_tool_keys_are_plain_letters() {
        compare(Editor.shortcut(Qt.Key_P, Qt.NoModifier, false), "tool:pencil")
        compare(Editor.shortcut(Qt.Key_T, Qt.NoModifier, false), "tool:text")
        compare(Editor.shortcut(Qt.Key_F, Qt.NoModifier, false), "tool:shape")
        compare(Editor.shortcut(Qt.Key_A, Qt.NoModifier, false), "tool:arrow")
        compare(Editor.shortcut(Qt.Key_P, Qt.ControlModifier, false), "")
        compare(Editor.shortcut(Qt.Key_Q, Qt.NoModifier, false), "")
    }

    function test_control_keys_save_copy_undo_and_redo() {
        compare(Editor.shortcut(Qt.Key_S, Qt.ControlModifier, false), "save")
        compare(Editor.shortcut(Qt.Key_C, Qt.ControlModifier, false), "copy")
        compare(Editor.shortcut(Qt.Key_Z, Qt.ControlModifier, false), "undo")
        compare(Editor.shortcut(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier, false), "redo")
        compare(Editor.shortcut(Qt.Key_Y, Qt.ControlModifier, false), "redo")
        compare(Editor.shortcut(Qt.Key_Plus, Qt.ControlModifier, false), "zoomIn")
        compare(Editor.shortcut(Qt.Key_Equal, Qt.ControlModifier, false), "zoomIn")
        compare(Editor.shortcut(Qt.Key_Minus, Qt.ControlModifier, false), "zoomOut")
        compare(Editor.shortcut(Qt.Key_0, Qt.ControlModifier, false), "zoomFit")
        compare(Editor.shortcut(Qt.Key_S, Qt.ControlModifier | Qt.AltModifier, false), "")
    }

    function test_escape_discards_when_no_text_is_being_typed() {
        compare(Editor.shortcut(Qt.Key_Escape, Qt.NoModifier, false), "discard")
    }

    function test_while_typing_the_text_keeps_its_keys_but_save_still_works() {
        compare(Editor.shortcut(Qt.Key_P, Qt.NoModifier, true), "")
        compare(Editor.shortcut(Qt.Key_C, Qt.ControlModifier, true), "")
        compare(Editor.shortcut(Qt.Key_Z, Qt.ControlModifier, true), "")
        compare(Editor.shortcut(Qt.Key_Escape, Qt.NoModifier, true), "")
        compare(Editor.shortcut(Qt.Key_S, Qt.ControlModifier, true), "save")
    }

    // --- the tools -------------------------------------------------------

    function test_the_tool_row_lists_the_four_tools_with_their_keys() {
        compare(Editor.tools.map(function (tool) { return tool.key }), ["pencil", "text", "shape", "arrow"])
        compare(Editor.tools.map(function (tool) { return tool.letter }), ["P", "T", "F", "A"])
    }
}
