import QtQuick
import QtTest
import "../../bar/layouts.js" as Layouts

// The bar's layout document (bar.ini `barLayout`): which elements its groups
// draw, in which order, per monitor, the density and fullscreen switches, the
// chips that share one pill and the dividers. An empty document is today's
// bar.
TestCase {
    name: "Layouts"

    readonly property var startIds: ["launcher", "workspaces", "notifications"]
    // Today's bar after the connection elements were folded into their chip.
    readonly property var endIds: ["capture", "recording", "tray", "@connections",
                                   "battery", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health",
                                   "keyboard", "power"]
    readonly property var connectionIds: ["network", "bluetooth", "vpn", "profile"]

    function test_the_empty_document_is_todays_bar() {
        var doc = Layouts.sanitize("")
        compare(doc.order.start, startIds)
        compare(doc.order.center, ["title", "media", "clock"])
        compare(doc.order.end, endIds)
        compare(doc.hidden, ["capture", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health"])
        compare(doc.chips.connections.members, connectionIds)
        compare(doc.density, "comfortable")
        compare(doc.hideFullscreen, true)
        compare(doc.monitors, {})
    }

    function test_the_workspace_pills_and_the_title_are_visible_by_default() {
        var doc = Layouts.sanitize("")
        verify(doc.order.start.indexOf("workspaces") >= 0)
        verify(doc.order.center.indexOf("title") >= 0)
        compare(doc.hidden.indexOf("workspaces"), -1)
        compare(doc.hidden.indexOf("title"), -1)
    }

    function test_defaults_cover_every_element_once() {
        var doc = Layouts.defaults("bar")
        var seen = []
        var inChip = []
        for (var group in doc.order) {
            for (var i = 0; i < doc.order[group].length; i++) {
                var entry = doc.order[group][i]
                if (Layouts.isChipToken(entry))
                    inChip = inChip.concat(Layouts.chipEntry(doc.chips,
                                                             Layouts.chipName(entry)).members)
                else
                    seen.push(entry)
            }
        }
        var expected = Layouts.widgets("bar").filter(function (widget) {
            return !widget.optional && doc.chips.connections.members.indexOf(widget.id) < 0
        }).map(function (widget) { return widget.id })
        compare(seen.length, expected.length)
        compare(seen.sort(), expected.sort())
        compare(inChip.sort(), connectionIds.slice().sort())
    }

    function test_the_divider_is_registered_but_never_shown_by_default() {
        var divider = Layouts.find("divider")
        verify(divider !== null)
        verify(divider.optional)
        verify(Layouts.isDivider("divider"))
        verify(Layouts.isDivider("divider-2"))
        verify(!Layouts.isDivider("divider-2x"))
        var doc = Layouts.defaults("bar")
        for (var group in doc.order)
            compare(doc.order[group].indexOf("divider"), -1)
    }

    function test_the_launcher_the_tray_and_the_power_button_are_fixed() {
        compare(Layouts.isFixed("launcher"), true)
        compare(Layouts.isFixed("tray"), true)
        compare(Layouts.isFixed("power"), true)
        compare(Layouts.isFixed("clock"), false)
        compare(Layouts.isFixed("network"), false)
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
        compare(doc.order.start, ["notifications", "launcher", "workspaces"])
        compare(doc.order.center, ["title", "media", "clock"])
        compare(doc.order.end, endIds)
        compare(doc.hidden, ["tray"])
    }

    function test_a_missing_element_returns_to_its_group() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: [], center: ["clock"], end: ["power"] }
        }))
        compare(doc.order.start, startIds)
        compare(doc.order.center, ["clock", "title", "media"])
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
        compare(doc.order.center, ["media", "title"])
    }

    function test_a_fixed_element_hand_moved_returns_to_its_group() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["launcher", "tray"], center: ["power"], end: [] }
        }))
        compare(doc.order.start.indexOf("launcher"), 0)
        compare(doc.order.start.indexOf("tray"), -1)
        compare(doc.order.center.indexOf("power"), -1)
        verify(doc.order.end.indexOf("tray") >= 0)
        verify(doc.order.end.indexOf("power") >= 0)
    }

    function test_effective_without_an_override_follows_the_globals() {
        var global = Layouts.sanitize(JSON.stringify({ hidden: ["tray"], density: "compact" }))
        var result = Layouts.effective(JSON.stringify(global), "DP-1")
        compare(result.order, global.order)
        compare(result.hidden, ["tray"])
        compare(result.chips, global.chips)
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
        compare(one.order.start, ["notifications", "launcher", "workspaces"])
        compare(one.order.center, ["clock", "media", "title"])
        var other = Layouts.effective(text, "HDMI-A-1")
        compare(other.hidden, [])
        compare(other.order.start, startIds)
    }

    function test_the_effective_document_is_never_the_documents_own_arrays() {
        var doc = Layouts.sanitize("")
        var result = Layouts.effective(JSON.stringify(doc), "")
        result.order.start.push("ghost")
        result.hidden.push("ghost")
        result.chips.connections.members.push("ghost")
        compare(doc.order.start, startIds)
        compare(doc.hidden, ["capture", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health"])
        compare(doc.chips.connections.members, connectionIds)
    }

    function test_effective_falls_back_to_the_defaults_given() {
        var base = Layouts.sanitize(JSON.stringify({ hidden: ["tray"] }))
        compare(Layouts.effective("", "DP-1", base).hidden, ["tray"])
    }

    function test_move_swaps_within_the_group_only() {
        var order = Layouts.defaults("bar").order
        var moved = Layouts.move(order, "clock", -1)
        compare(moved.center, ["title", "clock", "media"])
        compare(moved.start, startIds)
        compare(order.center, ["title", "media", "clock"])
        compare(Layouts.move(order, "launcher", -1).start, startIds)
        compare(Layouts.move(order, "launcher", 1).start, ["workspaces", "launcher", "notifications"])
        compare(Layouts.move(order, "launcher", 1).center, ["title", "media", "clock"])
    }

    function test_moveTo_moves_an_element_across_groups() {
        var order = Layouts.defaults("bar").order
        var moved = Layouts.moveTo(order, "clock", "start", 1)
        compare(moved.start, ["launcher", "clock", "workspaces", "notifications"])
        compare(moved.center, ["title", "media"])
        compare(order.center, ["title", "media", "clock"])
        moved = Layouts.moveTo(order, "workspaces", "center", 2)
        compare(moved.start, ["launcher", "notifications"])
        compare(moved.center, ["title", "media", "workspaces", "clock"])
    }

    function test_moveTo_keeps_the_chip_whole_and_moves_its_token() {
        var doc = Layouts.sanitize("")
        var moved = Layouts.moveTo(doc.order, "@connections", "start", 0)
        compare(moved.start[0], "@connections")
        compare(moved.end.indexOf("@connections"), -1)
        verify(moved.end.indexOf("network") < 0)
        compare(doc.order.end, endIds)
    }

    function test_moveTo_never_moves_a_fixed_element_out_of_its_group() {
        var order = Layouts.defaults("bar").order
        compare(Layouts.moveTo(order, "power", "start", 0), order)
        compare(Layouts.moveTo(order, "launcher", "end", 0), order)
        var moved = Layouts.moveTo(order, "power", "end", 0)
        compare(moved.end[0], "power")
        compare(moved.start, startIds)
    }

    function test_moveTo_clamps_and_never_changes_the_input() {
        var order = Layouts.defaults("bar").order
        var moved = Layouts.moveTo(order, "notifications", "start", 0)
        compare(moved.start, ["notifications", "launcher", "workspaces"])
        compare(Layouts.moveTo(order, "notifications", "start", 99).start,
                ["launcher", "workspaces", "notifications"])
        compare(Layouts.moveTo(order, "ghost", "start", 0), order)
        compare(Layouts.moveTo(order, "clock", "nowhere", 0), order)
        compare(order.start, startIds)
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

    // --- chips ---------------------------------------------------------------

    function test_chipOf_finds_the_chip_that_owns_an_element() {
        var chips = Layouts.defaults("bar").chips
        compare(Layouts.chipOf(chips, "network"), "connections")
        compare(Layouts.chipOf(chips, "profile"), "connections")
        compare(Layouts.chipOf(chips, "clock"), null)
        compare(Layouts.chipOf(chips, "ghost"), null)
        compare(Layouts.chipEntry(chips, "connections").members, connectionIds)
        compare(Layouts.chipEntry(chips, "nope"), null)
    }

    function test_entries_draw_a_chip_inside_one_pill() {
        var doc = Layouts.sanitize("")
        var entries = Layouts.entries(doc.order.end, doc.hidden, "bar", doc.chips)
        compare(entries.length, 6)
        compare(entries[0].id, "recording")
        compare(entries[1].id, "tray")
        compare(entries[2].chip, "connections")
        compare(entries[2].ids, connectionIds)
        compare(entries[3].id, "battery")
        compare(entries[4].id, "keyboard")
        compare(entries[5].id, "power")
    }

    function test_entries_leave_hidden_chip_members_out() {
        var chips = Layouts.defaults("bar").chips
        var entries = Layouts.entries(["@connections", "divider", "tray"],
                                      ["bluetooth", "capture"], "bar", chips)
        compare(entries[0].chip, "connections")
        compare(entries[0].ids, ["network", "vpn", "profile"])
        compare(entries[1].id, "divider")
        compare(entries[1].divider, true)
        compare(entries[2].id, "tray")
    }

    function test_a_chip_with_every_member_hidden_draws_nothing() {
        var chips = Layouts.defaults("bar").chips
        var entries = Layouts.entries(["@connections", "tray"], connectionIds, "bar", chips)
        compare(entries.length, 1)
        compare(entries[0].id, "tray")
    }

    function test_an_old_document_keeps_the_default_chip() {
        var text = JSON.stringify({
            order: { start: startIds, center: ["title", "media", "clock"],
                     end: ["capture", "recording", "tray", "network", "bluetooth",
                           "vpn", "profile", "battery", "keyboard", "power"] },
            hidden: ["capture"]
        })
        var doc = Layouts.sanitize(text)
        compare(doc.chips.connections.members, connectionIds)
        // "sample" and "volume" were absent from the old document, so cleanOrder appends them last
        compare(doc.order.end, ["capture", "recording", "tray", "@connections",
                                "battery", "keyboard", "power", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health"])
        var entries = Layouts.entries(doc.order.end, doc.hidden, "bar", doc.chips)
        compare(entries[2].ids, connectionIds)
    }

    function test_an_old_document_that_split_the_connection_elements_still_folds_them() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: [], center: [],
                     end: ["network", "tray", "vpn", "profile", "bluetooth"] }
        }))
        compare(doc.order.end[0], "@connections")
        compare(doc.order.end.indexOf("network"), -1)
        var entries = Layouts.entries(doc.order.end, [], "bar", doc.chips)
        compare(entries[0].chip, "connections")
        compare(entries[0].ids, connectionIds)
        compare(entries[1].id, "tray")
    }

    function test_a_declared_chip_replaces_the_built_in_one() {
        var text = JSON.stringify({
            chips: { work: { members: ["network", "vpn"] } },
            order: { start: ["launcher", "@work"], center: [], end: [] }
        })
        var doc = Layouts.sanitize(text)
        compare(doc.chips, { work: { members: ["network", "vpn"] } })
        compare(doc.order.start, ["launcher", "@work", "workspaces", "notifications"])
        verify(doc.order.end.indexOf("bluetooth") >= 0)
        verify(doc.order.end.indexOf("profile") >= 0)
        verify(doc.order.end.indexOf("network") < 0)
    }

    function test_an_unknown_or_duplicated_chip_member_drops() {
        var doc = Layouts.sanitize(JSON.stringify({
            chips: {
                one: { members: ["network", "ghost", "network", "launcher", "clock"] },
                two: { members: ["clock", "battery"] }
            },
            order: { start: ["@one"], center: ["@two"], end: [] }
        }))
        compare(doc.chips.one.members, ["network", "clock"])
        compare(doc.chips.two.members, ["battery"])
    }

    function test_the_fixed_elements_cannot_join_a_chip_or_a_divider() {
        var doc = Layouts.sanitize(JSON.stringify({
            chips: { mixed: { members: ["launcher", "tray", "power", "divider", "clock"] } },
            order: { start: ["launcher", "@mixed"], center: [], end: [] }
        }))
        compare(doc.chips.mixed.members, ["clock"])
    }

    function test_a_repeated_chip_token_places_the_chip_once() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["launcher", "@connections", "@connections"], center: [], end: [] }
        }))
        compare(doc.order.start, ["launcher", "@connections", "workspaces", "notifications"])
    }

    function test_a_declared_empty_chip_survives_and_draws_nothing() {
        var doc = Layouts.sanitize(JSON.stringify({
            chips: { empty: { members: [] } },
            order: { start: ["launcher", "@empty"], center: [], end: [] }
        }))
        compare(doc.chips.empty.members, [])
        compare(doc.order.start.indexOf("@empty"), 1)
        var entries = Layouts.entries(doc.order.start, [], "bar", doc.chips)
        compare(entries.length, 3)
        compare(entries[1].id, "workspaces")
        compare(entries[2].id, "notifications")
    }

    function test_new_chip_members_and_removal() {
        var doc = Layouts.defaults("bar")
        var made = Layouts.newChip(doc.order, doc.chips, "center")
        compare(made.id, "chip-1")
        compare(made.chips["chip-1"].members, [])
        compare(made.order.center[made.order.center.length - 1], "@chip-1")
        compare(doc.order.center, ["title", "media", "clock"])

        var result = Layouts.setChipMembers(made.order, made.chips, made.id, ["clock", "battery"])
        compare(result.chips["chip-1"].members, ["clock", "battery"])
        compare(result.order.center.indexOf("clock"), -1)
        compare(result.order.end.indexOf("battery"), -1)

        var removed = Layouts.removeChip(result.order, result.chips, "chip-1")
        compare(removed.chips["chip-1"], undefined)
        compare(removed.order.center.indexOf("@chip-1"), -1)
        verify(removed.order.center.indexOf("clock") >= 0)
        verify(removed.order.center.indexOf("battery") >= 0)
    }

    function test_a_chip_takes_a_member_from_another_chip() {
        var order = Layouts.defaults("bar").order
        var chips = { one: { members: ["network"] }, two: { members: ["bluetooth"] } }
        var result = Layouts.setChipMembers(order, chips, "one", ["network", "bluetooth"])
        compare(result.chips.one.members, ["network", "bluetooth"])
        compare(result.chips.two.members, [])
    }

    function test_an_element_leaving_a_chip_returns_next_to_it() {
        var doc = Layouts.sanitize("")
        var result = Layouts.setChipMembers(doc.order, doc.chips, "connections",
                                            ["network", "vpn"])
        compare(result.chips.connections.members, ["network", "vpn"])
        var end = result.order.end
        var at = end.indexOf("@connections")
        verify(at >= 0)
        compare(end[at + 1], "bluetooth")
        compare(end[at + 2], "profile")
        compare(end.indexOf("bluetooth", at + 3), -1)
    }

    function test_remove_chip_returns_its_members_where_the_chip_was() {
        var doc = Layouts.sanitize("")
        var result = Layouts.removeChip(doc.order, doc.chips, "connections")
        compare(result.chips.connections, undefined)
        var end = result.order.end
        compare(end, ["capture", "recording", "tray", "network", "bluetooth",
                      "vpn", "profile", "battery", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health", "keyboard", "power"])
    }

    function test_a_removed_default_chip_does_not_come_back() {
        var doc = Layouts.sanitize("")
        var result = Layouts.removeChip(doc.order, doc.chips, "connections")
        var text = Layouts.write("", "", { order: result.order, chips: result.chips })
        var written = Layouts.sanitize(text)
        compare(written.chips, {})
        compare(written.order.end.indexOf("@connections"), -1)
        compare(written.order.end.indexOf("network"), 3)
    }

    // --- dividers ------------------------------------------------------------

    function test_dividers_can_be_added_moved_and_removed() {
        var order = Layouts.defaults("bar").order
        var first = Layouts.addDivider(order, "center")
        compare(first.center[first.center.length - 1], "divider")
        var second = Layouts.addDivider(first, "center")
        compare(second.center[second.center.length - 1], "divider-2")
        compare(order.center, ["title", "media", "clock"])

        var moved = Layouts.moveTo(second, "divider-2", "start", 1)
        compare(moved.start, ["launcher", "divider-2", "workspaces", "notifications"])
        compare(moved.center[moved.center.length - 1], "divider")

        var removed = Layouts.removeDivider(moved, "divider-2")
        compare(removed.start, startIds)
        verify(removed.center.indexOf("divider") >= 0)
    }

    function test_a_document_keeps_its_dividers_in_every_group() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["divider", "launcher"], center: ["divider-2"], end: [] }
        }))
        compare(doc.order.start[0], "divider")
        compare(doc.order.center[0], "divider-2")
        compare(doc.order.start, ["divider", "launcher", "workspaces", "notifications"])
        var entries = Layouts.entries(doc.order.start, [], "bar", doc.chips)
        compare(entries[0].divider, true)
        compare(entries[0].id, "divider")
        compare(entries[1].id, "launcher")
    }

    function test_a_divider_may_be_hidden_and_a_ghost_divider_drops() {
        var doc = Layouts.sanitize(JSON.stringify({
            order: { start: ["divider", "launcher"], center: ["ghost"], end: [] },
            hidden: ["divider"]
        }))
        compare(doc.hidden, ["divider"])
        compare(doc.order.center, ["title", "media", "clock"])
        compare(Layouts.entries(doc.order.start, doc.hidden, "bar", doc.chips)[0].id, "launcher")
    }

    // --- the document --------------------------------------------------------

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
        compare(doc.chips.connections.members, connectionIds)
    }

    function test_write_records_chips_globally() {
        var doc = Layouts.defaults("bar")
        var result = Layouts.setChipMembers(doc.order, doc.chips, "connections",
                                            ["network", "vpn"])
        var text = Layouts.write("", "", { order: result.order, chips: result.chips })
        var written = Layouts.sanitize(text)
        compare(written.chips.connections.members, ["network", "vpn"])
        var at = written.order.end.indexOf("@connections")
        compare(written.order.end[at + 1], "bluetooth")
        compare(written.order.end[at + 2], "profile")
    }

    function test_write_records_a_monitor_override_and_keeps_the_rest() {
        var text = Layouts.write("", "DP-1", { hidden: ["tray"] })
        var doc = Layouts.sanitize(text)
        compare(doc.hidden, ["capture", "sample", "volume", "updates", "disks", "peripherals", "brightness", "health"])
        compare(doc.monitors["DP-1"].hidden, ["tray"])
        text = Layouts.write(text, "DP-1", { order: Layouts.move(doc.order, "clock", -1) })
        doc = Layouts.sanitize(text)
        compare(doc.monitors["DP-1"].order.center, ["title", "clock", "media"])
        compare(doc.monitors["DP-1"].hidden, ["tray"])
        compare(Layouts.effective(text, "DP-1").order.center, ["title", "clock", "media"])
        compare(Layouts.effective(text, "HDMI-A-1").order.center, ["title", "media", "clock"])
    }

    function test_a_monitor_override_keeps_its_chip_and_the_global_chips() {
        var doc = Layouts.defaults("bar")
        var result = Layouts.setChipMembers(doc.order, doc.chips, "connections",
                                            ["network", "vpn"])
        var order = Layouts.moveTo(result.order, "@connections", "start", 0)
        var text = Layouts.write("", "DP-1", { order: order, chips: result.chips })
        var doc2 = Layouts.sanitize(text)
        compare(doc2.chips.connections.members, ["network", "vpn"])
        compare(Layouts.effective(text, "DP-1").order.start[0], "@connections")
        compare(Layouts.effective(text, "HDMI-A-1").order.end,
                ["capture", "recording", "tray", "@connections", "battery",
                 "sample", "volume", "updates", "disks", "peripherals", "brightness", "health", "keyboard", "power", "bluetooth", "profile"])
    }

    function test_a_monitor_only_patch_is_not_a_global_change() {
        var text = Layouts.write("", "DP-1", { density: "compact" })
        compare(text, null)
    }
}
