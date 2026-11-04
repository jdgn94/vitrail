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
}
