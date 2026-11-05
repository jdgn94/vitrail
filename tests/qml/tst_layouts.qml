import QtQuick
import QtTest
import "../../bar/layouts.js" as Layouts

// The bar's layout document (bar.ini `barLayout`): which elements its groups
// draw, in which order, per monitor, and the density and fullscreen switches.
// An empty document is today's bar.
TestCase {
    name: "Layouts"

    readonly property var startIds: ["launcher", "notifications"]
    readonly property var endIds: ["capture", "recording", "tray", "network", "bluetooth",
                                   "vpn", "profile", "battery", "keyboard", "power"]

    function test_the_empty_document_is_todays_bar() {
        var doc = Layouts.sanitize("")
        compare(doc.order.start, startIds)
        compare(doc.order.center, ["media", "clock"])
        compare(doc.order.end, endIds)
        compare(doc.hidden, ["capture"])
        compare(doc.density, "comfortable")
        compare(doc.hideFullscreen, true)
        compare(doc.monitors, {})
    }

    function test_defaults_cover_every_element_once() {
        var doc = Layouts.defaults("bar")
        var seen = []
        for (var group in doc.order) {
            for (var i = 0; i < doc.order[group].length; i++)
                seen.push(doc.order[group][i])
        }
        compare(seen.length, Layouts.widgets("bar").length)
        compare(seen.sort(), Layouts.widgets("bar").map(function (widget) {
            return widget.id
        }).sort())
    }

    function test_invalid_json_is_the_default_document() {
        var bad = ["not json", "[]", "null", "1", '{"order":1}', '{"hidden":{}}']
        for (var i = 0; i < bad.length; i++)
            compare(JSON.stringify(Layouts.sanitize(bad[i])), JSON.stringify(Layouts.defaults("bar")))
    }

    function test_unknown_and_duplicate_ids_are_dropped() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["ghost", "notifications", "notifications"], center: [], end: [] },
            hidden: ["ghost", "tray", "tray"]
        }))
        compare(doc.order.start, ["notifications", "launcher"])
        compare(doc.order.center, ["media", "clock"])
        compare(doc.order.end, endIds)
        compare(doc.hidden, ["tray"])
    }

    function test_a_missing_element_returns_to_its_group() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: [], center: ["clock"], end: ["power"] }
        }))
        compare(doc.order.start, startIds)
        compare(doc.order.center, ["clock", "media"])
        compare(doc.order.end.length, endIds.length)
        compare(doc.order.end[0], "power")
        compare(doc.order.end[doc.order.end.length - 1], "keyboard")
    }

    function test_an_element_moved_by_hand_follows_its_new_group() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["launcher", "notifications", "clock"],
                     center: ["media"], end: endIds }
        }))
        compare(doc.order.start[2], "clock")
        compare(doc.order.center, ["media"])
    }

    function test_effective_without_an_override_follows_the_globals() {
        var global = Layouts.sanitize(JSON.stringify({ hidden: ["tray"], density: "compact" }))
        var result = Layouts.effective(JSON.stringify(global), "DP-1")
        compare(result.order, global.order)
        compare(result.hidden, ["tray"])
        compare(result.density, "compact")
        compare(result.hideFullscreen, true)
    }

    function test_a_monitor_override_replaces_hidden_and_order() {
        var text = JSON.stringify({
            hidden: [],
            monitors: {
                "DP-1": {
                    hidden: ["tray"],
                    order: { start: ["notifications", "launcher"],
                             center: ["clock", "media"],
                             end: endIds }
                }
            }
        })
        var one = Layouts.effective(text, "DP-1")
        compare(one.hidden, ["tray"])
        compare(one.order.start, ["notifications", "launcher"])
        compare(one.order.center, ["clock", "media"])
        var other = Layouts.effective(text, "HDMI-A-1")
        compare(other.hidden, [])
        compare(other.order.start, startIds)
    }

    function test_the_effective_document_is_never_the_documents_own_arrays() {
        var doc = Layouts.sanitize("")
        var result = Layouts.effective(JSON.stringify(doc), "")
        result.order.start.push("ghost")
        result.hidden.push("ghost")
        compare(doc.order.start, startIds)
        compare(doc.hidden, ["capture"])
    }

    function test_effective_falls_back_to_the_defaults_given() {
        var base = Layouts.sanitize(JSON.stringify({ hidden: ["tray"] }))
        compare(Layouts.effective("", "DP-1", base).hidden, ["tray"])
    }

    function test_move_swaps_within_the_group_only() {
        var order = Layouts.defaults("bar").order
        var moved = Layouts.move(order, "clock", -1)
        compare(moved.center, ["clock", "media"])
        compare(moved.start, startIds)
        compare(order.center, ["media", "clock"])
        compare(Layouts.move(order, "launcher", -1).start, startIds)
        compare(Layouts.move(order, "launcher", 1).start, ["notifications", "launcher"])
        compare(Layouts.move(order, "launcher", 1).center, ["media", "clock"])
    }

    function test_toggle_shows_and_hides_one_element() {
        var hidden = Layouts.toggle(["capture"], "tray")
        compare(hidden, ["capture", "tray"])
        compare(Layouts.toggle(hidden, "capture"), ["tray"])
        var original = ["capture"]
        Layouts.toggle(original, "tray")
        compare(original, ["capture"])
    }

    function test_visible_removes_the_hidden_ids_in_order() {
        compare(Layouts.visible(["a", "b", "c"], ["b"]), ["a", "c"])
        compare(Layouts.visible(undefined, []), [])
    }

    function test_entries_fold_neighbouring_connection_buttons_into_one_chip() {
        var entries = Layouts.entries(["tray", "network", "bluetooth", "vpn", "profile", "power"], [])
        compare(entries.length, 3)
        compare(entries[0].id, "tray")
        compare(entries[1].cluster, "connections")
        compare(entries[1].ids, ["network", "bluetooth", "vpn", "profile"])
        compare(entries[2].id, "power")
    }

    function test_entries_split_a_chip_around_another_element() {
        var entries = Layouts.entries(["network", "tray", "vpn", "profile"], [])
        compare(entries.length, 3)
        compare(entries[0].ids, ["network"])
        compare(entries[1].id, "tray")
        compare(entries[2].ids, ["vpn", "profile"])
    }

    function test_entries_leave_hidden_elements_out() {
        var entries = Layouts.entries(["network", "bluetooth", "tray"], ["bluetooth"])
        compare(entries[0].ids, ["network"])
        compare(entries[1].id, "tray")
    }

    function test_write_records_a_global_change_and_nothing_when_equal() {
        var text = Layouts.write("", "", { hidden: Layouts.toggle(["capture"], "tray") })
        compare(Layouts.sanitize(text).hidden, ["capture", "tray"])
        compare(Layouts.write(text, "", { hidden: ["capture", "tray"] }), null)
    }

    function test_write_keeps_the_other_fields() {
        var text = Layouts.write("", "", { density: "compact", hideFullscreen: false })
        var doc = Layouts.sanitize(text)
        compare(doc.density, "compact")
        compare(doc.hideFullscreen, false)
        compare(doc.order.start, startIds)
    }

    function test_write_records_a_monitor_override_and_keeps_the_rest() {
        var text = Layouts.write("", "DP-1", { hidden: ["tray"] })
        var doc = Layouts.sanitize(text)
        compare(doc.hidden, ["capture"])
        compare(doc.monitors["DP-1"].hidden, ["tray"])
        text = Layouts.write(text, "DP-1", { order: Layouts.move(doc.order, "clock", -1) })
        doc = Layouts.sanitize(text)
        compare(doc.monitors["DP-1"].order.center, ["clock", "media"])
        compare(doc.monitors["DP-1"].hidden, ["tray"])
        compare(Layouts.effective(text, "DP-1").order.center, ["clock", "media"])
        compare(Layouts.effective(text, "HDMI-A-1").order.center, ["media", "clock"])
    }

    function test_a_monitor_only_patch_is_not_a_global_change() {
        var text = Layouts.write("", "DP-1", { density: "compact" })
        compare(text, null)
    }
}
