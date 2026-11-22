import QtQuick
import QtTest
import "../../shell/monitorsview.js" as View

// The Monitors page's document handling and labels.
TestCase {
    name: "Monitors"

    readonly property var monitor: ({ name: "DP-1", width: 2560, height: 1440, refresh: 180,
                                      x: 0, y: 0, scale: 1, transform: 0, disabled: false,
                                      mirror: "", mode: "2560x1440@180.00",
                                      modes: ["2560x1440@59.95", "2560x1440@180.00"] })
    readonly property var second: ({ name: "HDMI-A-1", width: 1920, height: 1200, refresh: 59.95,
                                     x: 2560, y: 0, scale: 1.25, transform: 1, disabled: false,
                                     mirror: "", mode: "1920x1200@59.95", modes: ["1920x1200@59.95"] })

    function test_parse_is_tolerant() {
        compare(View.stringify(View.parse("")), "{}")
        compare(View.stringify(View.parse("not json")), "{}")
        compare(View.stringify(View.parse("[]")), "{}")
        compare(View.stringify(View.parse('{"DP-1":{"scale":1}}')), '{"DP-1":{"scale":1}}')
    }

    function test_seed_is_the_live_state() {
        var doc = View.seed(monitor)
        compare(doc.mode, "2560x1440@180.00")
        compare(doc.position, "0x0")
        compare(doc.scale, 1)
        compare(doc.disabled, false)
    }

    function test_update_seeds_then_merges() {
        var text = View.update("", "DP-1", { scale: 1.25 }, monitor)
        var doc = View.parse(text)
        compare(doc["DP-1"].scale, 1.25)
        compare(doc["DP-1"].mode, "2560x1440@180.00")
        compare(doc["DP-1"].position, "0x0")
    }

    function test_update_keeps_the_other_monitors() {
        var first = View.update("", "DP-1", { scale: 1.25 }, monitor)
        var both = View.update(first, "HDMI-A-1", { transform: 3 }, second)
        var doc = View.parse(both)
        compare(doc["DP-1"].scale, 1.25)
        compare(doc["HDMI-A-1"].transform, 3)
    }

    function test_update_is_null_when_nothing_changes() {
        // No override yet: the first edit pins the live state, so it writes.
        var text = View.update("", "DP-1", { scale: 1 }, monitor)
        compare(View.parse(text)["DP-1"].scale, 1)
        var existing = View.update("", "DP-1", { scale: 1.25 }, monitor)
        compare(View.update(existing, "DP-1", { scale: 1.25 }, monitor), null)
    }

    function test_remove_drops_only_that_monitor() {
        var text = View.update("", "DP-1", { scale: 1.25 }, monitor)
        var doc = View.parse(View.remove(text, "DP-1"))
        compare(doc["DP-1"], undefined)
        compare(View.remove(text, "HDMI-A-1"), null)
    }

    function test_labels() {
        compare(View.label(monitor), "2560 × 1440 · 180 Hz")
        compare(View.label(null), "")
        compare(View.modeLabel("2560x1440@180.00"), "2560 × 1440 · 180 Hz")
        compare(View.modeLabel("preferred"), "")
    }

    function test_the_current_mode_is_offered_once() {
        var list = View.modes(monitor)
        compare(list[0], "preferred")
        compare(list.length, 3)
        compare(list.indexOf("2560x1440@180.00"), 1 < list.indexOf("2560x1440@59.95") ? 1 : 2)
    }

    function test_rotation_maps_between_degrees_and_transform() {
        compare(View.transformOf(0), 0)
        compare(View.transformOf(90), 1)
        compare(View.transformOf(180), 2)
        compare(View.transformOf(270), 3)
        compare(View.degreesOf(1), 90)
        compare(View.degreesOf(4), 0)
    }

    function test_position() {
        compare(View.position({}), ({ auto: true, x: 0, y: 0 }))
        compare(View.position({ position: "auto-right" }).auto, true)
        compare(View.position({ position: "2560x0" }), ({ auto: false, x: 2560, y: 0 }))
        compare(View.position({ position: "-1920x120" }), ({ auto: false, x: -1920, y: 120 }))
    }

    function test_others_and_live() {
        var monitors = [monitor, second]
        compare(View.others(monitors, "DP-1"), ["HDMI-A-1"])
        compare(View.live(monitors, "HDMI-A-1"), second)
        compare(View.live(monitors, "nope"), null)
    }

    // --- the draft -----------------------------------------------------------

    function test_the_draft_seeds_every_output_and_one_primary() {
        var doc = View.draft([monitor, second], "", "")
        compare(Object.keys(doc).sort(), ["DP-1", "HDMI-A-1"])
        compare(doc["DP-1"].primary, true, "the focused output starts primary")
        compare(doc["HDMI-A-1"].primary, undefined)
        compare(doc["DP-1"].position, "0x0")
        compare(doc["HDMI-A-1"].position, "2560x0")
    }

    function test_a_saved_auto_position_stays_auto() {
        var doc = View.draft([monitor], '{"DP-1":{"position":"auto"}}', "DP-1")
        compare(doc["DP-1"].position, "auto")
        compare(doc["DP-1"].mode, "2560x1440@180.00")
    }

    function test_primary_is_only_one_and_can_move() {
        var doc = View.draft([monitor, second], "", "DP-1")
        var moved = View.setPrimary(doc, "HDMI-A-1")
        compare(moved["DP-1"].primary, undefined)
        compare(moved["HDMI-A-1"].primary, true)
        compare(View.primaryOf(moved), "HDMI-A-1")
    }

    function test_dragging_changes_the_draft_only() {
        var base = View.draft([monitor, second], "", "DP-1")
        var next = View.moveTo(base, [monitor, second], "DP-1", -1280, 120, false)
        compare(View.position(next["DP-1"]), ({ auto: false, x: -1280, y: 120 }))
        compare(base["DP-1"].position, "0x0", "the old draft is untouched")
    }

    function test_dropping_snaps_to_an_edge_without_overlapping() {
        var base = View.draft([monitor, second], "", "DP-1")
        // Dropped over the first output, nearer its right edge than any other.
        var moved = View.moveTo(base, [monitor, second], "HDMI-A-1", 1500, 30, false)
        var dropped = View.drop(moved, [monitor, second], "HDMI-A-1")
        var rect = View.rectOfName([monitor, second], dropped, "HDMI-A-1")
        var other = View.rectOfName([monitor, second], dropped, "DP-1")
        compare(rect.x, other.x + other.width, "it touches the first output's right edge")
        compare(View.rects([monitor, second], dropped).some(function (one, index, all) {
            return all.some(function (two) {
                return one.name !== two.name && View.overlaps(one, two)
            })
        }), false)
    }

    // --- joined layouts: no gaps, no overlap --------------------------------

    function box(name, x, y, width, height) {
        return { name: name, x: x, y: y, width: width, height: height }
    }

    function fake(name, width, height) {
        return { name: name, width: width, height: height, refresh: 60, x: 0, y: 0, scale: 1,
                 transform: 0, disabled: false, mirror: "", mode: width + "x" + height + "@60.00",
                 modes: [width + "x" + height + "@60.00"] }
    }

    function test_touching_needs_a_shared_edge_segment() {
        var one = box("A", 0, 0, 100, 100)
        verify(View.touching(one, box("B", 100, 20, 100, 100)), "right edge, overlapping rows")
        verify(View.touching(one, box("B", -40, 100, 100, 100)), "bottom edge, overlapping columns")
        verify(!View.touching(one, box("B", 100, 100, 100, 100)), "a corner is not an edge")
        verify(!View.touching(one, box("B", 110, 0, 100, 100)), "a gap")
        verify(!View.touching(one, box("B", 50, 50, 100, 100)), "overlap is not touching")
    }

    function test_a_drop_below_with_a_gap_moves_up_flush_keeping_its_x() {
        var top = box("A", 0, 0, 2560, 1440)
        var at = View.snap({ width: 2560, height: 1440 }, [top], 200, 1500)
        compare(at, ({ x: 200, y: 1440 }), "flush below, same offset")
    }

    function test_the_offset_along_the_edge_is_clamped_to_still_overlap() {
        var top = box("A", 0, 0, 2560, 1440)
        var moving = { width: 1000, height: 800 }
        var at = View.snap(moving, [top], 2800, 3000)
        compare(JSON.stringify(at), JSON.stringify({ x: 2528, y: 1440 }), "pulled back until it shares a segment of the edge")
        verify(View.touching(box("M", at.x, at.y, 1000, 800), top))
    }

    function test_a_drop_over_another_output_is_pushed_to_the_nearest_edge() {
        var other = box("A", 0, 0, 2560, 1440)
        var moving = { width: 1920, height: 1200 }
        compare(View.snap(moving, [other], 1500, 60), ({ x: 2560, y: 60 }), "nearer its right edge")
        compare(View.snap(moving, [other], 100, 1000), ({ x: 100, y: 1440 }), "nearer its bottom edge")
        compare(View.snap(moving, [other], -1000, 70), ({ x: -1920, y: 70 }), "nearer its left edge")
    }

    function test_a_far_diagonal_drop_still_touches_the_nearest_edge() {
        var other = box("A", 0, 0, 2560, 1440)
        var moving = { width: 1000, height: 800 }
        var at = View.snap(moving, [other], 5000, 4000)
        var rect = box("M", at.x, at.y, 1000, 800)
        verify(View.touching(rect, other), "touches")
        verify(!View.overlaps(rect, other), "does not overlap")
    }

    function test_the_offset_snaps_to_aligned_edges_and_centre_within_the_threshold() {
        var other = box("A", 0, 0, 2560, 1440)
        var moving = { width: 1000, height: 800 }
        compare(View.snap(moving, [other], 2600, 660), ({ x: 2560, y: 640 }), "bottoms line up")
        compare(View.snap(moving, [other], 2600, 20), ({ x: 2560, y: 0 }), "tops line up")
        compare(View.snap(moving, [other], 2600, 300), ({ x: 2560, y: 320 }), "centres line up")
        compare(View.snap(moving, [other], 2600, 500), ({ x: 2560, y: 500 }), "far from any: the user's offset")
    }

    function test_the_snapped_place_never_overlaps_a_third_output() {
        var one = box("A", 0, 0, 1000, 1000)
        var two = box("B", 1000, 0, 1000, 1000)
        var moving = { width: 1000, height: 1000 }
        // Over the seam: the nearest touching places are above or below both.
        var at = View.snap(moving, [one, two], 500, 300)
        var rect = box("M", at.x, at.y, 1000, 1000)
        verify(!View.overlaps(rect, one) && !View.overlaps(rect, two))
        verify(View.touching(rect, one) || View.touching(rect, two))
    }

    function test_the_layout_stays_one_group_when_the_middle_output_leaves() {
        var three = [fake("A", 1000, 1000), fake("B", 1000, 1000), fake("C", 1000, 1000)]
        var doc = View.draft(three, JSON.stringify({ "A": { position: "0x0" }, "B": { position: "1000x0" },
                                                    "C": { position: "2000x0" } }), "A")
        // B goes above A: C would be left alone two screens away.
        doc = View.moveTo(doc, three, "B", 0, -1000, false)
        doc = View.drop(doc, three, "B")
        var list = View.rects(three, doc)
        verify(View.connected(list), "one group")
        compare(View.rectOfName(three, doc, "B").y, -1000, "the dropped output stays where it was put")
        compare(View.position(doc["A"]), ({ auto: false, x: 0, y: 0 }), "the group it joined does not move")
        compare(View.position(doc["C"]), ({ auto: false, x: 1000, y: 0 }), "the stranded one closes the gap")
        verify(!list.some(function (one) {
            return list.some(function (two) { return one.name !== two.name && View.overlaps(one, two) })
        }), "no overlap")
    }

    function test_a_dropped_output_can_reach_the_far_end() {
        var three = [fake("A", 1000, 1000), fake("B", 1000, 1000), fake("C", 1000, 1000)]
        var doc = View.draft(three, JSON.stringify({ "A": { position: "0x0" }, "B": { position: "1000x0" },
                                                    "C": { position: "2000x0" } }), "A")
        doc = View.moveTo(doc, three, "A", 5000, 100, false)
        doc = View.drop(doc, three, "A")
        verify(View.connected(View.rects(three, doc)))
        compare(View.rectOfName(three, doc, "A").x, 3000, "right of the last output")
    }

    function test_a_stranded_group_is_pulled_along_the_axis_it_shares() {
        var list = [box("A", 0, 0, 1000, 1000), box("B", 3000, 200, 500, 500)]
        var moves = View.tidy(list, "A")
        compare(moves, [{ name: "B", x: 1000, y: 200 }])
    }

    function test_guides_mark_the_coordinates_that_line_up() {
        var other = box("A", 0, 0, 2560, 1440)
        var list = View.guides(box("M", 2560, 20, 2560, 1440), [other], 58)
        function has(axis, at, kind) {
            return list.some(function (guide) {
                return guide.axis === axis && guide.at === at && guide.kind === kind
            })
        }
        verify(has("x", 2560, "flush"), "the shared edge")
        verify(has("y", 0, "edge"), "tops")
        verify(has("y", 1440, "edge"), "bottoms")
        verify(has("y", 720, "centre"), "centres")
        compare(View.guides(box("M", 6000, 3000, 100, 100), [other], 58), [], "nothing near")
    }

    function test_guides_use_each_other_output_and_drop_duplicates() {
        var list = View.guides(box("M", 0, 1440, 2560, 1440),
                               [box("A", 0, 0, 2560, 1440), box("B", 0, 0, 2560, 1440)], 58)
        compare(list.filter(function (guide) { return guide.axis === "x" && guide.at === 0 }).length, 1)
        verify(list.some(function (guide) { return guide.axis === "y" && guide.at === 1440 && guide.kind === "flush" }))
    }

    function test_the_document_is_canonical_and_dirty_only_with_a_difference() {
        var base = View.draft([monitor, second], "", "DP-1")
        var same = View.copy(base)
        compare(View.dirty(base, same), false)
        compare(View.documentText(base), View.documentText(same))
        var next = View.set(base, [monitor, second], "DP-1", { scale: 1.25 })
        compare(View.dirty(base, next), true)
        compare(View.changed(base, next), ["DP-1"])
        compare(View.countChanges(base, next), 1)
    }

    function test_the_canvas_fits_the_logical_extents() {
        compare(View.extent(monitor, { transform: 1, scale: 1 }), ({ width: 1440, height: 2560 }))
        compare(View.extent(second, { transform: 0, scale: 2 }), ({ width: 960, height: 600 }))
        var box = View.bounds(View.rects([monitor, second], View.draft([monitor, second], "", "DP-1")))
        compare(box, ({ x: 0, y: 0, width: 3520, height: 1536 }))
    }

    function test_the_tile_names_the_resolution_it_will_have() {
        compare(View.sizeText(monitor, { mode: "preferred" }), "2560×1440")
        compare(View.sizeText(monitor, null), "2560×1440")
        compare(View.sizeText(monitor, { mode: "1920x1080@60.00" }), "1920×1080")
    }

    function test_the_indicator_document_round_trips() {
        var text = View.indicator("DP-1", true)
        compare(View.parseIndicator(text), ({ active: true, name: "DP-1" }))
        compare(View.parseIndicator(View.indicator("DP-1", false)), ({ active: false, name: "" }))
        compare(View.parseIndicator("not json"), ({ active: false, name: "" }))
    }
}
