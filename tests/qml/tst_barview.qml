import QtQuick
import QtTest
import "../../bar/barview.js" as BarView

// The bar's per-monitor overrides: one JSON object in bar.ini, keyed by the
// Hyprland output name. Only edge and style may differ from the global bar.
TestCase {
    name: "BarView"

    readonly property var defaults: ({ edge: "left", style: "" })

    function test_without_an_override_follows_the_globals() {
        var result = BarView.forMonitor("{}", "DP-1", defaults)
        compare(result, defaults)
        compare(result.edge, "left")
        compare(result.style, "")
    }

    function test_an_override_replaces_the_edge_and_the_style() {
        var result = BarView.forMonitor('{"DP-1":{"edge":"top","style":"floating"}}', "DP-1", defaults)
        compare(result, { edge: "top", style: "floating" })
    }

    function test_an_override_may_name_only_one_of_them() {
        var result = BarView.forMonitor('{"DP-1":{"style":"islands"}}', "DP-1", defaults)
        compare(result, { edge: "left", style: "islands" })
    }

    function test_another_monitor_follows_the_globals() {
        compare(BarView.forMonitor('{"HDMI-A-1":{"edge":"bottom"}}', "DP-1", defaults), defaults)
    }

    function test_invalid_json_follows_the_globals() {
        compare(BarView.forMonitor("not json", "DP-1", defaults), defaults)
        compare(BarView.forMonitor("[]", "DP-1", defaults), defaults)
        compare(BarView.forMonitor("null", "DP-1", defaults), defaults)
        compare(BarView.forMonitor('{"DP-1":1}', "DP-1", defaults), defaults)
        compare(BarView.forMonitor('{"DP-1":{"edge":1}}', "DP-1", defaults), defaults)
    }

    function test_the_defaults_are_never_changed() {
        var original = { edge: "left", style: "docked" }
        var result = BarView.forMonitor('{"DP-1":{"edge":"top"}}', "DP-1", original)
        compare(original, { edge: "left", style: "docked" })
        compare(result, { edge: "top", style: "docked" })
    }

    function test_no_unknown_key_is_invented() {
        var result = BarView.forMonitor('{"DP-1":{"edge":"top","size":80}}', "DP-1", defaults)
        compare(Object.keys(result).sort(), ["edge", "style"])
        compare(result.size, undefined)
    }

    function test_update_writes_one_monitor_and_keeps_the_rest() {
        var text = BarView.update("{}", "DP-1", { edge: "top" })
        compare(BarView.document(text), { "DP-1": { edge: "top" } })
        text = BarView.update(text, "HDMI-A-1", { style: "floating" })
        compare(BarView.document(text), {
            "DP-1": { edge: "top" },
            "HDMI-A-1": { style: "floating" }
        })
    }

    function test_clearing_the_last_override_drops_the_monitor() {
        var text = BarView.update("{}", "DP-1", { edge: "top", style: "floating" })
        compare(BarView.update(text, "DP-1", { edge: "", style: "" }), "{}")
    }
}
