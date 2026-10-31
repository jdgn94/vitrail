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
    readonly property var islands: ({ docked: true, islands: true })
    readonly property var floatingIslands: ({ docked: false, islands: true })

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

    function test_docked_islands_keep_the_frame_thin_but_reserve_the_bar() {
        var l = Frame.layout(full, islands, "top", sizes)
        compare(l.hole, { left: 6, top: 6, right: 6, bottom: 6 })
        compare(l.reserve, { left: 6, top: 36, right: 6, bottom: 6 })
        compare(l.bar.offset, 0)
        compare(l.bar.padding, 6)
    }

    function test_cards_dock_past_the_islands_and_into_a_plain_docked_bar() {
        compare(Frame.layout(full, islands, "top", sizes).dock, { left: 6, top: 36, right: 6, bottom: 6 })
        compare(Frame.layout(full, docked, "left", sizes).dock, { left: 36, top: 6, right: 6, bottom: 6 })
        // A full panel pushes the hole past the islands.
        var l = Frame.layout(full, islands, "left", sizes, { variant: { attached: true }, extent: 380, push: true })
        compare(l.dock.left, 36 + 380)
    }

    function test_stack_hangs_below_the_islands() {
        var l = Frame.layout(full, islands, "top", sizes)
        compare(Frame.stackRect("top-right", 1000, 800, 300, 200, l, true, 12),
                { x: 1000 - 6 - 300, y: 36, edge: "top" })
    }

    function test_floating_islands_lay_out_like_a_floating_bar() {
        var l = Frame.layout(full, floatingIslands, "right", sizes)
        compare(l.hole, { left: 6, top: 6, right: 6, bottom: 6 })
        compare(l.reserve.right, 6 + 8 + 36)
        compare(l.bar.offset, 6 + 8)
    }

    function test_islands_without_a_frame_border_start_at_the_screen() {
        var l = Frame.layout(corners, islands, "left", sizes)
        compare(l.hole, { left: 0, top: 0, right: 0, bottom: 0 })
        compare(l.reserve.left, 36)
    }

    readonly property var groups: [
        { at: "start", rect: Qt.rect(20, 3, 100, 30) },
        { at: "center", rect: Qt.rect(450, 3, 100, 30) },
        { at: "end", rect: Qt.rect(860, 3, 120, 30) }]
    readonly property var barSizes: ({ bar: 36, pad: 8, inset: 0 })

    function test_docked_islands_merge_into_the_screen_ends() {
        compare(Frame.islands(groups, "top", 1000, 700, barSizes, true), [
            { x: 0, y: 0, width: 128, height: 36 },
            { x: 442, y: 0, width: 116, height: 36 },
            { x: 852, y: 0, width: 148, height: 36 }])
    }

    function test_floating_islands_are_separate_pills_inset_from_the_edge() {
        compare(Frame.islands(groups, "top", 1000, 700, { bar: 36, pad: 8, inset: 14 }, false), [
            { x: 12, y: 14, width: 116, height: 36 },
            { x: 442, y: 14, width: 116, height: 36 },
            { x: 852, y: 14, width: 136, height: 36 }])
    }

    function test_islands_follow_every_edge() {
        var column = [{ at: "start", rect: Qt.rect(3, 20, 30, 100) }, { at: "end", rect: Qt.rect(3, 560, 30, 100) }]
        compare(Frame.islands(column, "left", 1000, 700, barSizes, true), [
            { x: 0, y: 0, width: 36, height: 128 }, { x: 0, y: 552, width: 36, height: 148 }])
        compare(Frame.islands(column, "right", 1000, 700, barSizes, true), [
            { x: 964, y: 0, width: 36, height: 128 }, { x: 964, y: 552, width: 36, height: 148 }])
        compare(Frame.islands(groups, "bottom", 1000, 700, barSizes, true)[1],
                { x: 442, y: 664, width: 116, height: 36 })
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

    readonly property var tall: ({ left: 36, top: 6, right: 6, bottom: 6 })
    readonly property string rest: " L184 6 A10 10 0 0 1 194 16 L194 184 A10 10 0 0 1 184 194"
                                   + " L46 194 A10 10 0 0 1 36 184 Z"

    function tab(y, h, depth, reveal) {
        return { edge: "left", rect: Qt.rect(36, y, depth, h), reveal: reveal === undefined ? 1 : reveal }
    }

    function test_a_tab_rising_out_of_a_wider_one_steps_up_and_back() {
        // Island 40..160 (depth 20) with a popup 80..120 (depth 60) on it.
        var path = Frame.holePath(200, 200, tall, 10, [tab(40, 120, 20), tab(80, 40, 60)])
        compare(path, "M36 170 A10 10 0 0 1 46 160 L46 160 A10 10 0 0 0 56 150"
                + " L56 130 A10 10 0 0 1 66 120 L86 120 A10 10 0 0 0 96 110"
                + " L96 90 A10 10 0 0 0 86 80 L66 80 A10 10 0 0 1 56 70"
                + " L56 50 A10 10 0 0 0 46 40 L46 40 A10 10 0 0 1 36 30"
                + " L36 16 A10 10 0 0 1 46 6" + rest)
    }

    function test_the_order_of_the_tabs_does_not_matter() {
        compare(Frame.holePath(200, 200, tall, 10, [tab(80, 40, 60), tab(40, 120, 20)]),
                Frame.holePath(200, 200, tall, 10, [tab(40, 120, 20), tab(80, 40, 60)]))
    }

    function test_adjacent_tabs_of_different_depth_make_a_stepped_profile() {
        var path = Frame.holePath(200, 200, tall, 10, [tab(100, 60, 60), tab(40, 60, 20)])
        compare(path, "M36 170 A10 10 0 0 1 46 160 L86 160 A10 10 0 0 0 96 150"
                + " L96 110 A10 10 0 0 0 86 100 L66 100 A10 10 0 0 1 56 90"
                + " L56 50 A10 10 0 0 0 46 40 L46 40 A10 10 0 0 1 36 30"
                + " L36 16 A10 10 0 0 1 46 6" + rest)
    }

    function test_adjacent_tabs_of_equal_depth_merge() {
        compare(Frame.holePath(200, 200, tall, 10, [tab(40, 60, 40), tab(100, 60, 40)]),
                Frame.holePath(200, 200, tall, 10, [tab(40, 120, 40)]))
    }

    function test_a_tab_inside_a_deeper_one_adds_nothing() {
        compare(Frame.holePath(200, 200, tall, 10, [tab(40, 120, 60), tab(80, 40, 20)]),
                Frame.holePath(200, 200, tall, 10, [tab(40, 120, 60)]))
    }

    function test_a_step_is_rounded_by_half_of_its_height() {
        // 8 px step (20 -> 28): both corners shrink to 4.
        var path = Frame.holePath(200, 200, tall, 10, [tab(40, 120, 20), tab(80, 40, 28)])
        verify(path.indexOf("A4 4 0 0 1 60 120") > 0, path)
        verify(path.indexOf("A4 4 0 0 0 64 116") > 0, path)
    }

    function test_an_island_flush_with_the_end_keeps_taking_the_corner() {
        // Island 0..80 (depth 20) against the top end, a popup 30..50 on it.
        var path = Frame.holePath(200, 200, tall, 10, [tab(0, 80, 20), tab(30, 20, 60)])
        compare(path, "M36 90 A10 10 0 0 1 46 80 L46 80 A10 10 0 0 0 56 70"
                + " L56 60 A10 10 0 0 1 66 50 L86 50 A10 10 0 0 0 96 40"
                + " L96 40 A10 10 0 0 0 86 30 L66 30 A10 10 0 0 1 56 20"
                + " L56 16 A10 10 0 0 1 66 6" + rest)
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

    // --- liquid motion --------------------------------------------------------
    readonly property var liquidTokens: ({ overshoot: 1.1, spreadEnd: 0.7, swellEnd: 0.8, swell: 0.9, pull: 0.9,
                                           snapAt: 0.45, contentAt: 0.55, stretch: 0.12 })
    readonly property var smoothTokens: ({ contentAt: 0.4, scale: 0.96, shift: 6, stretch: 0 })

    function test_liquid_starts_closed_and_ends_settled() {
        var a = Frame.liquid(0, liquidTokens)
        compare(a.reveal, 0)
        compare(a.spread, 0)
        compare(a.content, 0)
        compare(a.bond, 1)
        var z = Frame.liquid(1, liquidTokens)
        fuzzyCompare(z.reveal, 1, 1e-9)
        fuzzyCompare(z.spread, 1, 1e-9)
        fuzzyCompare(z.swell, 1, 1e-9)
        fuzzyCompare(z.pull, 0, 1e-9)
        fuzzyCompare(z.content, 1, 1e-9)
        compare(z.bond, 0)
    }

    function test_liquid_depth_overshoots_a_little_then_settles() {
        var peak = 0
        for (var t = 0; t <= 1.0001; t += 0.01)
            peak = Math.max(peak, Frame.liquid(t, liquidTokens).reveal)
        verify(peak > 1.02 && peak < 1.08, "peak " + peak)
        verify(Frame.liquid(0.99, liquidTokens).reveal < peak)
    }

    function test_liquid_time_outside_the_timeline_is_clamped() {
        compare(Frame.liquid(-1, liquidTokens).reveal, 0)
        fuzzyCompare(Frame.liquid(2, liquidTokens).reveal, 1, 1e-9)
    }

    function test_liquid_fillets_swell_while_it_moves() {
        verify(Frame.liquid(0.4, liquidTokens).swell > 1.5)
        compare(Frame.liquid(0, liquidTokens).swell, 1)
    }

    function test_liquid_content_waits_for_the_shape() {
        compare(Frame.liquid(0.3, liquidTokens).content, 0)
        compare(Frame.liquid(0.55, liquidTokens).content, 0)
        verify(Frame.liquid(0.8, liquidTokens).content > 0.3)
    }

    function test_liquid_neck_thins_and_snaps() {
        var before = 1
        for (var t = 0.05; t < 0.45; t += 0.05) {
            var bond = Frame.liquid(t, liquidTokens).bond
            verify(bond < before, "bond at " + t)
            before = bond
        }
        compare(Frame.liquid(0.45, liquidTokens).bond, 0)
        compare(Frame.liquid(0.9, liquidTokens).bond, 0)
    }

    function test_smooth_has_no_overshoot_stretch_or_neck() {
        for (var t = 0; t <= 1.0001; t += 0.05) {
            var look = Frame.smooth(t, smoothTokens)
            verify(look.reveal <= 1 + 1e-9)
            compare(look.spread, 1)
            compare(look.swell, 1)
            compare(look.bond, 0)
            compare(look.grow, 1)
        }
    }

    function test_smooth_fades_and_scales_in_from_the_bar() {
        var a = Frame.smooth(0, smoothTokens)
        compare(a.fade, 0)
        compare(a.scale, 0.96)
        compare(a.shift, 6)
        var z = Frame.smooth(1, smoothTokens)
        compare(z.fade, 1)
        fuzzyCompare(z.scale, 1, 1e-9)
        fuzzyCompare(z.shift, 0, 1e-9)
    }

    function test_liquid_rect_grows_from_the_button_along_the_bar() {
        var card = Qt.rect(100, 40, 300, 120)
        var button = Qt.rect(180, 0, 30, 36)
        compare(Frame.liquidRect(card, "top", button, 0, 0, 0), Qt.rect(180, 40, 30, 120))
        compare(Frame.liquidRect(card, "top", button, 1, 0, 0), card)
        compare(Frame.liquidRect(card, "top", button, 0.5, 0, 0), Qt.rect(140, 40, 165, 120))
        // A vertical bar runs along y.
        compare(Frame.liquidRect(Qt.rect(36, 100, 200, 300), "left", Qt.rect(0, 180, 36, 30), 0, 0, 0),
                Qt.rect(36, 180, 200, 30))
    }

    function test_liquid_rect_without_a_button_starts_at_its_centre() {
        compare(Frame.liquidRect(Qt.rect(100, 40, 300, 120), "top", null, 0, 0, 0), Qt.rect(250, 40, 0, 120))
    }

    function test_liquid_rect_stretches_ahead_of_the_motion() {
        var card = Qt.rect(100, 40, 300, 120)
        // The card still has 50 px to go forwards: its leading end reaches out.
        compare(Frame.liquidRect(card, "top", null, 1, 50, 0.2), Qt.rect(100, 40, 310, 120))
        compare(Frame.liquidRect(card, "top", null, 1, -50, 0.2), Qt.rect(90, 40, 310, 120))
        compare(Frame.liquidRect(Qt.rect(36, 100, 200, 300), "left", null, 1, 50, 0.2), Qt.rect(36, 100, 200, 310))
    }

    function test_a_revealed_tab_starts_at_the_island_depth() {
        var island = { edge: "left", rect: Qt.rect(0, 100, 36, 60), reveal: 1 }
        var tall = { edge: "left", rect: Qt.rect(36, 110, 200, 40), reveal: 0, base: 30 }
        compare(Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10, [island, tall]),
                Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10, [island]))
        tall.reveal = 1
        var open = Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10, [island, tall])
        verify(open.indexOf("L236 ") > 0, open)
        tall.reveal = 0.5
        var half = Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10, [island, tall])
        // 30 + (230 - 30) / 2 + the hole's 6 px = 136
        verify(half.indexOf("L136 ") > 0, half)
    }

    function test_a_swollen_tab_has_larger_fillets() {
        var plain = Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10,
                                   [{ edge: "left", rect: Qt.rect(6, 100, 200, 100), reveal: 1 }])
        var swollen = Frame.holePath(400, 300, { left: 6, top: 6, right: 6, bottom: 6 }, 10,
                                     [{ edge: "left", rect: Qt.rect(6, 100, 200, 100), reveal: 1, swell: 1.5 }])
        verify(plain.indexOf("A10 10") > 0)
        verify(swollen.indexOf("A15 15 0 0 0") > 0, swollen)
    }

    function test_the_neck_thins_as_the_card_leaves() {
        var island = Qt.rect(100, 0, 200, 36)
        var card = Qt.rect(150, 48, 120, 80)
        var thick = Frame.neck(400, 300, "top", island, card, 1, 14)
        var thin = Frame.neck(400, 300, "top", island, card, 0.3, 14)
        verify(thick.path.indexOf("M") === 0 && thick.path.indexOf("Q") > 0, thick.path)
        verify(thin.waist < thick.waist)
        verify(thin.waist > 0)
        compare(thick.length, 12)
    }

    function test_the_neck_is_gone_once_it_snaps_or_when_nothing_faces_the_card() {
        var island = Qt.rect(100, 0, 200, 36)
        compare(Frame.neck(400, 300, "top", island, Qt.rect(150, 48, 120, 80), 0, 14), null)
        compare(Frame.neck(400, 300, "top", island, Qt.rect(320, 48, 60, 80), 1, 14), null)
        // Touching: no gap to bridge yet.
        compare(Frame.neck(400, 300, "top", island, Qt.rect(150, 36, 120, 80), 1, 14), null)
    }

    function test_a_narrow_island_still_gets_a_neck() {
        var neck = Frame.neck(400, 300, "top", Qt.rect(190, 0, 20, 36), Qt.rect(150, 48, 120, 80), 1, 14)
        verify(neck !== null)
        verify(neck.width <= 20)
    }

    function test_the_neck_stays_between_the_island_and_the_card_on_every_edge() {
        // Right edge: the island is the right-hand one, the card to its left.
        var neck = Frame.neck(400, 300, "right", Qt.rect(364, 50, 36, 200), Qt.rect(252, 100, 100, 100), 1, 10)
        verify(neck !== null)
        var numbers = neck.path.replace(/[A-Za-z]/g, " ").trim().split(/\s+/).map(Number)
        for (var i = 0; i < numbers.length; i += 2)
            verify(numbers[i] >= 352 - 1e-6 && numbers[i] <= 364 + 1e-6, "x " + numbers[i])
    }

    function test_a_floating_card_grows_out_of_the_bar_face() {
        var card = Qt.rect(100, 48, 300, 120)
        var button = Qt.rect(180, 6, 30, 36)
        var closed = Frame.floatRect(card, "top", button, Frame.liquid(0, liquidTokens), 12, 0)
        compare(closed.y, 36)
        compare(closed.height, 0)
        compare(closed.width, 30)
        var open = Frame.floatRect(card, "top", button, Frame.liquid(1, liquidTokens), 12, 0)
        fuzzyCompare(open.y, 48, 1e-6)
        fuzzyCompare(open.height, 120, 1e-6)
        fuzzyCompare(open.width, 300, 1e-6)
        // Away from the bar it detaches further than at rest, then settles.
        var mid = Frame.floatRect(card, "top", button, Frame.liquid(0.4, liquidTokens), 12, 0)
        verify(mid.y > 36 + 12 * 0.9, "mid " + mid.y)
    }

    function test_a_floating_card_hangs_the_right_way_on_every_edge() {
        var look = Frame.liquid(0, liquidTokens)
        var bottom = Frame.floatRect(Qt.rect(100, 500, 300, 100), "bottom", null, look, 12, 0)
        compare(bottom.y, 612)
        compare(bottom.height, 0)
        var right = Frame.floatRect(Qt.rect(600, 100, 100, 300), "right", null, look, 12, 0)
        compare(right.x, 712)
        var left = Frame.floatRect(Qt.rect(48, 100, 100, 300), "left", null, look, 12, 0)
        compare(left.x, 36)
    }

    function test_a_smooth_floating_card_slides_in_from_the_bar_scaled_down() {
        var card = Qt.rect(100, 48, 300, 120)
        var shown = Frame.floatRect(card, "top", null, Frame.smooth(0, smoothTokens), 12, 0)
        compare(shown.y, 48 - 6)
        compare(shown.width, 300 * 0.96)
        compare(shown.height, 120 * 0.96)
        var rest = Frame.floatRect(card, "top", null, Frame.smooth(1, smoothTokens), 12, 0)
        fuzzyCompare(rest.y, 48, 1e-6)
        fuzzyCompare(rest.width, 300, 1e-6)
    }

    function test_nearest_rect_prefers_the_one_under_the_point() {
        var rects = [Qt.rect(0, 0, 100, 36), Qt.rect(200, 0, 100, 36), Qt.rect(500, 0, 100, 36)]
        compare(Frame.nearestRect(rects, 250, 10), rects[1])
        compare(Frame.nearestRect(rects, 400, 10), rects[1])
        compare(Frame.nearestRect(rects, 490, 10), rects[2])
        compare(Frame.nearestRect([], 0, 0), null)
    }

    function test_stack_hangs_from_the_island_it_overlaps_and_from_the_frame_otherwise() {
        var l = Frame.layout(full, islands, "top", sizes)
        var rects = [Qt.rect(0, 0, 200, 36), Qt.rect(800, 0, 200, 36)]
        // top-right: 700..1000 overlaps the island at 800.
        compare(Frame.stackRect("top-right", 1000, 800, 300, 200, l, true, 12, rects),
                { x: 1000 - 6 - 300, y: 36, edge: "top" })
        // top-center: 350..650 sits between the islands.
        compare(Frame.stackRect("top-center", 1000, 800, 300, 200, l, true, 12, rects),
                { x: 6 + (1000 - 12 - 300) / 2, y: 6, edge: "top" })
        // Without islands given, it keeps hanging past the bar.
        compare(Frame.stackRect("top-center", 1000, 800, 300, 200, l, true, 12).y, 36)
    }

    function test_stack_on_the_far_edge_of_an_islands_bar_hangs_from_the_frame() {
        var l = Frame.layout(full, islands, "top", sizes)
        compare(Frame.stackRect("bottom-right", 1000, 800, 300, 200, l, true, 12, [Qt.rect(800, 0, 200, 36)]),
                { x: 1000 - 6 - 300, y: 800 - 6 - 200, edge: "bottom" })
    }

    // A tooltip sits a gap past the bar, on the side away from its edge,
    // centred on the element and kept a gap inside the screen.
    function test_tooltip_hangs_away_from_the_bar_edge() {
        var target = Qt.rect(500, 0, 40, 36)
        compare(Frame.tooltipAt("top", target, 100, 30, 36, 8, 1000, 800), { x: 470, y: 44 })
        compare(Frame.tooltipAt("bottom", Qt.rect(500, 764, 40, 36), 100, 30, 36, 8, 1000, 800), { x: 470, y: 800 - 36 - 8 - 30 })
        compare(Frame.tooltipAt("left", Qt.rect(0, 300, 36, 40), 100, 30, 36, 8, 1000, 800), { x: 44, y: 305 })
        compare(Frame.tooltipAt("right", Qt.rect(964, 300, 36, 40), 100, 30, 36, 8, 1000, 800), { x: 1000 - 36 - 8 - 100, y: 305 })
    }

    function test_tooltip_stays_inside_the_screen() {
        compare(Frame.tooltipAt("top", Qt.rect(0, 0, 20, 36), 100, 30, 36, 8, 1000, 800).x, 8)
        compare(Frame.tooltipAt("top", Qt.rect(980, 0, 20, 36), 100, 30, 36, 8, 1000, 800).x, 1000 - 100 - 8)
        compare(Frame.tooltipAt("left", Qt.rect(0, 0, 36, 20), 100, 30, 36, 8, 1000, 800).y, 8)
    }
}
