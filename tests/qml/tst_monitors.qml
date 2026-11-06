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
        compare(View.positionText({ auto: true, x: 0, y: 0 }), "auto")
        compare(View.positionText({ auto: false, x: 2560, y: 0 }), "2560x0")
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
        var moved = View.moveTo(base, [monitor, second], "HDMI-A-1", 1200, 30, false)
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

    function test_the_indicator_document_round_trips() {
        var text = View.indicator("DP-1", true)
        compare(View.parseIndicator(text), ({ active: true, name: "DP-1" }))
        compare(View.parseIndicator(View.indicator("DP-1", false)), ({ active: false, name: "" }))
        compare(View.parseIndicator("not json"), ({ active: false, name: "" }))
    }
}
