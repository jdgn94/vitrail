import QtQuick
import QtTest
import "../../bar/capture/capture.js" as Capture

// Geometry of the capture overlay: the selection, its handles and the toolbar's
// seat. No Quickshell, no window: the same functions the overlay calls.
TestCase {
    name: "CaptureGeometry"

    readonly property var screen: ({ x: 0, y: 0, w: 1920, h: 1080 })
    readonly property var area: ({ x: 800, y: 100, w: 400, h: 300 })

    function test_a_drag_normalizes_in_every_direction() {
        compare(Capture.normalize({ x: 100, y: 100 }, { x: 300, y: 250 }), { x: 100, y: 100, w: 200, h: 150 })
        compare(Capture.normalize({ x: 300, y: 250 }, { x: 100, y: 100 }), { x: 100, y: 100, w: 200, h: 150 })
        compare(Capture.normalize({ x: 300, y: 100 }, { x: 100, y: 250 }), { x: 100, y: 100, w: 200, h: 150 })
    }

    function test_move_stops_at_the_layout_edges() {
        compare(Capture.move(area, -1000, 0, screen), { x: 0, y: 100, w: 400, h: 300 })
        compare(Capture.move(area, 1000, 0, screen), { x: 1520, y: 100, w: 400, h: 300 })
        compare(Capture.move(area, 0, 1000, screen), { x: 800, y: 780, w: 400, h: 300 })
        compare(Capture.move(area, 10, -10, screen), { x: 810, y: 90, w: 400, h: 300 })
    }

    function test_every_handle_moves_its_own_edges() {
        compare(Capture.resize(area, "e", 50, 0, screen, 1), { x: 800, y: 100, w: 450, h: 300 })
        compare(Capture.resize(area, "w", 50, 0, screen, 1), { x: 850, y: 100, w: 350, h: 300 })
        compare(Capture.resize(area, "s", 0, 50, screen, 1), { x: 800, y: 100, w: 400, h: 350 })
        compare(Capture.resize(area, "n", 0, 50, screen, 1), { x: 800, y: 150, w: 400, h: 250 })
        compare(Capture.resize(area, "nw", 50, 50, screen, 1), { x: 850, y: 150, w: 350, h: 250 })
        compare(Capture.resize(area, "se", -50, -50, screen, 1), { x: 800, y: 100, w: 350, h: 250 })
        compare(Capture.resize(area, "ne", -50, 50, screen, 1), { x: 800, y: 150, w: 350, h: 250 })
        compare(Capture.resize(area, "sw", 50, -50, screen, 1), { x: 850, y: 100, w: 350, h: 250 })
    }

    function test_a_handle_never_crosses_the_other_edge() {
        var tiny = Capture.resize(area, "e", -1000, 0, screen, 1)
        compare(tiny.w, 1)
        compare(tiny.x, 800)
        var flipped = Capture.resize(area, "w", 1000, 0, screen, 1)
        compare(flipped.w, 1)
        compare(flipped.x, 1199)
    }

    function test_a_handle_never_leaves_the_layout() {
        compare(Capture.resize(area, "n", 0, -500, screen, 1), { x: 800, y: 0, w: 400, h: 400 })
        compare(Capture.resize(area, "se", 2000, 2000, screen, 1), { x: 800, y: 100, w: 1120, h: 980 })
    }

    function test_the_pointer_finds_the_handle_it_is_on() {
        compare(Capture.handleAt({ x: 800, y: 100 }, area, 6), "nw")
        compare(Capture.handleAt({ x: 1200, y: 100 }, area, 6), "ne")
        compare(Capture.handleAt({ x: 1200, y: 400 }, area, 6), "se")
        compare(Capture.handleAt({ x: 800, y: 400 }, area, 6), "sw")
        compare(Capture.handleAt({ x: 1000, y: 100 }, area, 6), "n")
        compare(Capture.handleAt({ x: 1200, y: 250 }, area, 6), "e")
        compare(Capture.handleAt({ x: 1000, y: 400 }, area, 6), "s")
        compare(Capture.handleAt({ x: 800, y: 250 }, area, 6), "w")
        compare(Capture.handleAt({ x: 1000, y: 250 }, area, 6), "inside")
        compare(Capture.handleAt({ x: 100, y: 100 }, area, 6), "")
    }

    function test_the_toolbar_sits_under_the_area() {
        var seat = Capture.toolbarPlacement(area, screen, { w: 400, h: 44 })
        compare(seat, { x: 800, y: 408 })
    }

    function test_the_toolbar_goes_above_when_there_is_no_room_below() {
        var low = { x: 800, y: 700, w: 400, h: 350 }
        compare(Capture.toolbarPlacement(low, screen, { w: 400, h: 44 }), { x: 800, y: 648 })
    }

    function test_the_toolbar_goes_inside_when_neither_fits() {
        var full = { x: 0, y: 0, w: 1920, h: 1080 }
        compare(Capture.toolbarPlacement(full, screen, { w: 400, h: 44 }), { x: 760, y: 1028 })
    }

    function test_the_toolbar_never_leaves_the_monitor_sideways() {
        compare(Capture.toolbarPlacement({ x: 1800, y: 100, w: 100, h: 100 }, screen, { w: 400, h: 44 }).x, 1512)
        compare(Capture.toolbarPlacement({ x: 0, y: 100, w: 100, h: 100 }, screen, { w: 400, h: 44 }).x, 8)
    }

    function test_the_label_rounds_the_size() {
        compare(Capture.label({ x: 0, y: 0, w: 1280, h: 720 }), "1280 × 720")
        compare(Capture.label({ x: 0, y: 0, w: 1280.4, h: 719.6 }), "1280 × 720")
        compare(Capture.label(null), "")
    }

    function test_a_point_translates_between_layout_and_monitor() {
        var monitor = ({ x: 1920, y: 0, width: 1280, height: 1024, scale: 1.5 })
        compare(Capture.toLocal({ x: 2000, y: 100 }, monitor), { x: 80, y: 100 })
        compare(Capture.toLayout({ x: 80, y: 100 }, monitor), { x: 2000, y: 100 })
        compare(Capture.toLocalRect({ x: 1920, y: 0, w: 100, h: 50 }, monitor), { x: 0, y: 0, w: 100, h: 50 })
    }

    function test_the_bounds_cover_every_monitor() {
        var monitors = [
            { x: 0, y: 0, width: 1920, height: 1080, scale: 1 },
            { x: 1920, y: 0, width: 1280, height: 1024, scale: 1.5 },
        ]
        compare(Capture.boundsOf(monitors), { x: 0, y: 0, w: 3200, h: 1080 })
    }

    readonly property var tension: ({ rest: 6, swell: 0.12, max: 28, bow: 0.4, bowMax: 48 })

    function test_a_drop_is_centred_on_its_point_and_is_a_goo_box() {
        compare(Capture.dropAt({ x: 100, y: 50 }, 14), { x: 93, y: 43, w: 14, h: 14 })
        compare(Capture.boxOf({ x: 1, y: 2, w: 3, h: 4 }), { x: 1, y: 2, width: 3, height: 4 })
        compare(Capture.centreOf({ x: 10, y: 20, w: 100, h: 40 }), { x: 60, y: 40 })
    }

    function test_strain_is_the_widest_edge_still_to_travel() {
        var exact = { x: 100, y: 100, w: 200, h: 100 }
        compare(Capture.strain(exact, exact), 0)
        compare(Capture.strain(exact, { x: 90, y: 100, w: 200, h: 100 }), 10)
        compare(Capture.strain(exact, { x: 100, y: 100, w: 150, h: 100 }), 50)
        compare(Capture.strain(null, exact), 0)
    }

    function test_the_radius_swells_with_the_strain_and_settles_at_rest() {
        var exact = { x: 100, y: 100, w: 400, h: 300 }
        compare(Capture.softRadius(exact, exact, tension), 6)
        fuzzyCompare(Capture.softRadius(exact, { x: 50, y: 100, w: 400, h: 300 }, tension), 12, 0.001)
        compare(Capture.softRadius(exact, { x: -2000, y: 100, w: 400, h: 300 }, tension), 28)
        compare(Capture.softRadius(exact, null, tension), 6)
    }

    function test_a_drop_stays_a_circle_whatever_the_strain() {
        var exact = { x: 100, y: 100, w: 400, h: 300 }
        compare(Capture.softRadius(exact, Capture.dropAt({ x: 100, y: 100 }, 14), tension), 7)
        compare(Capture.softRadius({ x: 0, y: 0, w: 0, h: 0 }, { x: 0, y: 0, w: 0, h: 0 }, tension), 0)
    }

    function test_a_growing_edge_bulges_ahead_and_a_trailing_one_dents() {
        // The area is being dragged right: its right edge still has 100 px to
        // go (outward), its left edge 100 px too but inward.
        var exact = { x: 300, y: 100, w: 400, h: 300 }
        var shown = { x: 200, y: 100, w: 400, h: 300 }
        var bows = Capture.edgeBows(exact, shown, tension)
        compare(bows.e, 40)
        compare(bows.w, -40)
        compare(bows.n, 0)
        compare(bows.s, 0)
        compare(Capture.edgeBows(exact, exact, tension), { n: 0, e: 0, s: 0, w: 0 })
        compare(Capture.edgeBows(null, shown, tension), { n: 0, e: 0, s: 0, w: 0 })
    }

    function test_a_bow_never_exceeds_the_cap_or_a_fifth_of_the_short_side() {
        var exact = { x: 0, y: 0, w: 2000, h: 2000 }
        var big = Capture.edgeBows(exact, { x: 1000, y: 1000, w: 500, h: 500 }, tension)
        compare(big.e, 48)
        var tiny = Capture.edgeBows(exact, { x: 1000, y: 1000, w: 20, h: 20 }, tension)
        compare(tiny.e, 4)
        compare(tiny.w, 4)
    }

    function test_the_outline_bows_each_side_by_its_own_amount() {
        var flat = Capture.outline({ x: 0, y: 0, w: 100, h: 60 }, { n: 0, e: 0, s: 0, w: 0 }, 6)
        verify(flat.indexOf("M6 0 C") === 0)
        verify(flat.indexOf("Z") === flat.length - 1)
        var bowed = Capture.outline({ x: 0, y: 0, w: 100, h: 60 }, { n: 0, e: 15, s: 0, w: 0 }, 6)
        // The right side's control points leave x = 100 by 4/3 of the bow.
        verify(bowed.indexOf("120 ") >= 0)
        verify(flat.indexOf("120 ") < 0)
        compare(Capture.outline({ x: 0, y: 0, w: 0, h: 10 }, { n: 0, e: 0, s: 0, w: 0 }, 6), "")
        // A radius larger than the sides is a circle at most.
        var drop = Capture.outline({ x: 0, y: 0, w: 14, h: 14 }, { n: 0, e: 0, s: 0, w: 0 }, 40)
        verify(drop.indexOf("M7 0 C") === 0)
    }

    function test_the_grips_follow_the_bowed_sides_and_rounded_corners() {
        var rect = { x: 100, y: 100, w: 200, h: 100 }
        var points = Capture.grips(rect, { n: -5, e: 10, s: 0, w: 3 }, 0)
        compare(points.length, 8)
        compare(points[0], ["nw", 100, 100])
        compare(points[1], ["n", 200, 105])
        compare(points[3], ["e", 310, 150])
        compare(points[7], ["w", 97, 150])
        var round = Capture.grips(rect, { n: 0, e: 0, s: 0, w: 0 }, 20)
        verify(round[0][1] > 100 && round[0][1] < 106)
    }

    function test_the_question_is_one_trimmed_line() {
        compare(Capture.question("  what is\n  this\t? "), "what is this ?")
        compare(Capture.question(""), "")
        compare(Capture.question(null), "")
    }

    function test_the_question_is_capped() {
        compare(Capture.question("x".repeat(2000)).length, Capture.QUESTION_MAX)
    }

    readonly property var monitors: [
        { name: "DP-1", x: 0, y: 0, width: 2560, height: 1440, scale: 1 },
        { name: "DP-2", x: 2560, y: 0, width: 1920, height: 1080, scale: 2 }
    ]

    function test_a_pin_belongs_to_the_monitor_the_area_starts_on() {
        compare(Capture.monitorOf({ x: 100, y: 100, w: 3000, h: 100 }, monitors).name, "DP-1")
        compare(Capture.monitorOf({ x: 2600, y: 10, w: 100, h: 100 }, monitors).name, "DP-2")
        compare(Capture.monitorOf({ x: 9000, y: 10, w: 100, h: 100 }, monitors), null)
    }

    function test_a_pin_opens_where_the_area_was_and_fits_its_monitor() {
        var start = Capture.pinStart({ x: 2660, y: 50, w: 400, h: 300 }, monitors[1])
        compare(start, { x: 100, y: 50, zoom: 1 })
        var big = Capture.pinStart({ x: 0, y: 0, w: 5120, h: 1440 }, monitors[0])
        compare(big.zoom, 0.5)
        var edge = Capture.pinStart({ x: 2500, y: 1400, w: 400, h: 300 }, monitors[0])
        verify(edge.x + 400 <= 2560 && edge.y + 300 <= 1440)
    }

    function test_the_wheel_zooms_around_the_pointer() {
        var pin = { x: 100, y: 100, zoom: 1 }
        var out = Capture.pinZoom(pin, 2, { x: 150, y: 120 }, 0.1, 8)
        compare(out.zoom, 2)
        compare(out.x, 50)
        compare(out.y, 80)
        var same = Capture.pinZoom(out, 0.5, { x: 150, y: 120 }, 0.1, 8)
        compare(same.x, 100)
        compare(same.y, 100)
    }

    function test_the_zoom_stays_between_its_limits() {
        compare(Capture.pinZoom({ x: 0, y: 0, zoom: 7 }, 3, { x: 0, y: 0 }, 0.1, 8).zoom, 8)
        compare(Capture.pinZoom({ x: 0, y: 0, zoom: 0.2 }, 0.1, { x: 0, y: 0 }, 0.1, 8).zoom, 0.1)
    }

    function test_the_opacity_stays_between_its_limits() {
        compare(Capture.pinOpacity(0.5, 0.25, 0.2), 0.75)
        compare(Capture.pinOpacity(0.95, 0.25, 0.2), 1)
        compare(Capture.pinOpacity(0.3, -0.25, 0.2), 0.2)
    }

    function test_a_share_reads_as_a_whole_percent() {
        compare(Capture.shareLabel(0.4104), "41%")
        compare(Capture.shareLabel(0.0225), "2%")
        compare(Capture.shareLabel(0.004), "<1%")
        compare(Capture.shareLabel(1), "100%")
    }

    function test_only_one_web_link_is_a_link() {
        verify(Capture.isUrl("https://example.org/a?b=1"))
        verify(Capture.isUrl("http://example.org"))
        verify(!Capture.isUrl("example.org"))
        verify(!Capture.isUrl("file:///etc/passwd"))
        verify(!Capture.isUrl("https://a.b and more"))
    }

    function test_a_detection_is_kept_only_for_the_selection_it_was_asked_for() {
        compare(Capture.fresh(3, 3), true)
        compare(Capture.fresh(2, 3), false)
    }

    // The drawn edges: one damped spring each, stepped by hand every frame.
    // (the values of kit/tokens.js capture.liquid)
    readonly property var liquid: ({ spring: 16000, damping: 0.65, mass: 1, epsilon: 0.25 })
    readonly property var critical: ({ spring: 16000, damping: 1, mass: 1, epsilon: 0.25 })

    function chase(params, from, to, frames, dt) {
        var state = { x: from, v: 0 }
        var peak = from
        for (var i = 0; i < frames; ++i) {
            state = Capture.springStep(state, to, dt, params)
            peak = to > from ? Math.max(peak, state.x) : Math.min(peak, state.x)
        }
        return { state: state, peak: peak }
    }

    function test_a_liquid_edge_overshoots_then_rests_on_the_target() {
        var run = chase(liquid, 0, 100, 120, 1 / 60)
        verify(run.peak > 105, "overshoot " + run.peak)
        verify(run.peak < 120, "overshoot " + run.peak)
        compare(run.state.x, 100)
        compare(run.state.v, 0)
        compare(Capture.springStep({ x: 100, v: 0 }, 100, 1 / 60, liquid).rest, true)
    }

    function test_a_released_edge_rests_within_a_quarter_second() {
        var state = { x: 0, v: 0 }
        for (var i = 0; i < 15; ++i)
            state = Capture.springStep(state, 100, 1 / 60, liquid)
        compare(state.x, 100)
    }

    function test_a_dragged_edge_stays_within_a_few_px_of_a_steady_pointer() {
        // 300 px/s, retargeted every millisecond, a frame every 16 ms
        var state = { x: 0, v: 0 }
        var target = 0
        var gap = 0
        for (var ms = 1; ms <= 1000; ++ms) {
            target = ms * 0.3
            if (ms % 16 === 0) {
                state = Capture.springStep(state, target, 0.016, liquid)
                if (ms > 300)
                    gap = Math.max(gap, target - state.x)
            }
        }
        verify(gap < 8, "gap " + gap)
    }

    function test_a_critically_damped_edge_never_overshoots() {
        var state = { x: 0, v: 0 }
        for (var i = 0; i < 120; ++i) {
            state = Capture.springStep(state, 100, 1 / 60, critical)
            verify(state.x <= 100 + 1e-9, "x " + state.x)
        }
        compare(state.x, 100)
    }

    function test_the_step_does_not_depend_on_how_the_time_is_cut() {
        var one = Capture.springStep({ x: 0, v: 0 }, 100, 1 / 30, liquid)
        var two = Capture.springStep(Capture.springStep({ x: 0, v: 0 }, 100, 1 / 60, liquid), 100, 1 / 60, liquid)
        verify(Math.abs(one.x - two.x) < 1e-6)
        verify(Math.abs(one.v - two.v) < 1e-6)
    }

    function test_a_long_frame_is_clamped() {
        var long = Capture.springStep({ x: 0, v: 0 }, 100, 5, liquid)
        var capped = Capture.springStep({ x: 0, v: 0 }, 100, 1 / 30, liquid)
        compare(long.x, capped.x)
        compare(Capture.springStep({ x: 0, v: 0 }, 100, -1, liquid).x, 0)
    }

    function test_retargeting_every_millisecond_keeps_the_velocity_and_follows() {
        // A pointer at 2000 px/s, a new target each millisecond, one frame per 16 ms.
        var state = { x: 0, v: 0 }
        var target = 0
        var worst = 0
        for (var ms = 1; ms <= 1000; ++ms) {
            target = ms * 2
            if (ms % 16 === 0) {
                state = Capture.springStep(state, target, 0.016, liquid)
                if (ms > 200)
                    worst = Math.max(worst, target - state.x)
            }
        }
        verify(state.x > 1800, "reached " + state.x)
        // trailing distance at constant speed is 2 * damping * v / omega
        verify(worst < 40, "trailed " + worst)
        // and it keeps converging once the pointer stops
        for (var i = 0; i < 120; ++i)
            state = Capture.springStep(state, target, 1 / 60, liquid)
        compare(state.x, target)
    }
}
