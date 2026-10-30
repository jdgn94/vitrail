import QtQuick
import QtTest
import "../../kit/frame.js" as Frame

// Geometry of the screen frame for every frame × bar × edge combination.
TestCase {
    name: "FrameLayout"

    readonly property var sizes: ({ frame: 6, bar: 36, gap: 8, radius: 14 })
    readonly property var full: ({ border: true, corners: true })
    readonly property var corners: ({ border: false, corners: true })
    readonly property var none: ({ border: false, corners: false })
    readonly property var docked: ({ docked: true })
    readonly property var floating: ({ docked: false })

    function test_full_docked_merges_the_bar_into_the_frame() {
        var l = Frame.layout(full, docked, "left", sizes)
        compare(l.hole, { left: 36, top: 6, right: 6, bottom: 6 })
        compare(l.reserve, l.hole)
        compare(l.radius, 14)
        compare(l.bar.offset, 0)
    }

    function test_corners_keeps_only_the_rounded_corners() {
        var l = Frame.layout(corners, docked, "top", sizes)
        compare(l.hole, { left: 0, top: 36, right: 0, bottom: 0 })
        compare(l.radius, 14)
    }

    function test_none_draws_a_plain_bar() {
        var l = Frame.layout(none, docked, "bottom", sizes)
        compare(l.hole, { left: 0, top: 0, right: 0, bottom: 36 })
        compare(l.radius, 0)
    }

    function test_floating_bar_sits_inside_the_frame() {
        var l = Frame.layout(full, floating, "right", sizes)
        compare(l.hole, { left: 6, top: 6, right: 6, bottom: 6 })
        compare(l.reserve.right, 6 + 8 + 36)
        compare(l.bar.offset, 6 + 8)
        compare(l.bar.margin, 6 + 8)
    }

    function test_docked_padding_clears_the_inner_corners() {
        var l = Frame.layout(full, docked, "left", sizes)
        compare(l.bar.padding, 6 + 14)
    }

    function test_screen_without_bar_keeps_only_the_frame() {
        var l = Frame.layout(full, null, "left", sizes)
        compare(l.hole, { left: 6, top: 6, right: 6, bottom: 6 })
        compare(l.reserve, l.hole)
        compare(l.radius, 14)
    }

    function test_full_panel_grows_the_frame_and_pushes_windows() {
        var l = Frame.layout(full, docked, "left", sizes,
                             { variant: { attached: true }, extent: 380, push: true })
        compare(l.hole.left, 36 + 380)
        compare(l.reserve.left, 36 + 380)
        compare(l.panel.start, 36)
        compare(l.panel.edge, "left")
    }

    function test_full_panel_without_push_leaves_windows_alone() {
        var l = Frame.layout(full, docked, "left", sizes,
                             { variant: { attached: true }, extent: 380, push: false })
        compare(l.hole.left, 36 + 380)
        compare(l.reserve.left, 36)
    }

    function test_overlay_panel_changes_nothing() {
        var l = Frame.layout(full, docked, "top", sizes,
                             { variant: { attached: false }, extent: 380, push: true })
        compare(l.hole, { left: 6, top: 36, right: 6, bottom: 6 })
        compare(l.reserve, l.hole)
        compare(l.panel.start, 36 + 8)
    }

    function test_full_panel_opens_past_a_floating_bar() {
        var l = Frame.layout(full, floating, "left", sizes,
                             { variant: { attached: true }, extent: 380, push: true })
        compare(l.panel.start, 6 + 8 + 36)
        compare(l.hole.left, 6 + 8 + 36 + 380)
    }

    function test_closed_panel_changes_nothing() {
        var l = Frame.layout(full, docked, "left", sizes,
                             { variant: { attached: true }, extent: 0, push: true })
        compare(l.hole.left, 36)
        compare(l.reserve.left, 36)
        var f = Frame.layout(full, floating, "left", sizes,
                             { variant: { attached: true }, extent: 0, push: true })
        compare(f.hole.left, 6)
    }

    readonly property var hole: ({ left: 36, top: 6, right: 6, bottom: 6 })
    readonly property string rightAndBottom: " A10 10 0 0 1 194 16 L194 84 A10 10 0 0 1 184 94 L46 94 A10 10 0 0 1 36 84 Z"

    function test_hole_path_without_tabs_is_the_rounded_hole() {
        compare(Frame.holePath(200, 100, hole, 10, []),
                "M36 16 A10 10 0 0 1 46 6 L184 6" + rightAndBottom)
    }

    function test_hole_path_bends_around_a_docked_tab() {
        var path = Frame.holePath(200, 100, hole, 10, [{ edge: "left", rect: Qt.rect(36, 40, 60, 20), reveal: 1 }])
        compare(path, "M36 70 A10 10 0 0 1 46 60 L86 60 A10 10 0 0 0 96 50 L96 50 A10 10 0 0 0 86 40"
                + " L46 40 A10 10 0 0 1 36 30 L36 16 A10 10 0 0 1 46 6 L184 6" + rightAndBottom)
    }

    function test_tab_flush_with_the_top_takes_the_corner() {
        var path = Frame.holePath(200, 100, hole, 10, [{ edge: "left", rect: Qt.rect(36, 6, 60, 20), reveal: 1 }])
        compare(path, "M36 36 A10 10 0 0 1 46 26 L86 26 A10 10 0 0 0 96 16 L96 16 A10 10 0 0 1 106 6"
                + " L184 6" + rightAndBottom)
    }

    function test_tab_flush_with_the_bottom_takes_the_corner() {
        var path = Frame.holePath(200, 100, hole, 10, [{ edge: "left", rect: Qt.rect(36, 74, 60, 20), reveal: 1 }])
        compare(path, "M106 94 A10 10 0 0 1 96 84 L96 84 A10 10 0 0 0 86 74 L46 74 A10 10 0 0 1 36 64"
                + " L36 16 A10 10 0 0 1 46 6 L184 6 A10 10 0 0 1 194 16 L194 84 A10 10 0 0 1 184 94 Z")
    }

    function test_tab_on_another_edge_takes_the_corner_it_touches() {
        // Hanging from the top, flush with the right side.
        var path = Frame.holePath(200, 100, hole, 10, [{ edge: "top", rect: Qt.rect(134, 6, 60, 20), reveal: 1 }])
        compare(path, "M36 16 A10 10 0 0 1 46 6 L124 6 A10 10 0 0 1 134 16 L134 16 A10 10 0 0 0 144 26"
                + " L184 26 A10 10 0 0 1 194 36 L194 84 A10 10 0 0 1 184 94 L46 94 A10 10 0 0 1 36 84 Z")
    }

    function test_hidden_tab_leaves_no_bump() {
        compare(Frame.holePath(200, 100, hole, 10, [{ edge: "top", rect: Qt.rect(50, 6, 40, 30), reveal: 0 }]),
                Frame.holePath(200, 100, hole, 10, []))
    }

    function test_stack_hangs_flush_from_a_docked_frame() {
        var l = Frame.layout(full, docked, "left", sizes)
        compare(Frame.stackRect("top-right", 1000, 800, 300, 200, l, true, 12),
                { x: 1000 - 6 - 300, y: 6, edge: "top" })
        compare(Frame.stackRect("bottom-left", 1000, 800, 300, 200, l, true, 12),
                { x: 36, y: 800 - 6 - 200, edge: "bottom" })
        compare(Frame.stackRect("top-center", 1000, 800, 300, 200, l, true, 12),
                { x: 36 + (1000 - 36 - 6 - 300) / 2, y: 6, edge: "top" })
    }

    function test_floating_stack_keeps_clear_of_the_bar_and_frame() {
        var l = Frame.layout(full, floating, "left", sizes)
        compare(Frame.stackRect("top-left", 1000, 800, 300, 200, l, false, 12),
                { x: 6 + 8 + 36 + 12, y: 6 + 12, edge: "top" })
    }

    function test_docked_popup_centres_on_its_anchor() {
        compare(Frame.popupAlong(500, 100, 6, 1000, true, 12, 14), 450)
    }

    function test_docked_popup_near_an_edge_snaps_to_it() {
        compare(Frame.popupAlong(60, 100, 6, 1000, true, 12, 14), 6)
        compare(Frame.popupAlong(960, 100, 6, 1000, true, 12, 14), 900)
    }

    function test_floating_popup_keeps_a_gap_from_the_frame() {
        compare(Frame.popupAlong(60, 100, 6, 1000, false, 12, 14), 18)
        compare(Frame.popupAlong(960, 100, 6, 1000, false, 12, 14), 888)
    }

    function test_unknown_edge_falls_back_to_left() {
        compare(Frame.layout(full, docked, "diagonal", sizes).edge, "left")
    }
}
