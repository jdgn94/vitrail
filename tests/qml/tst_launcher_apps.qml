import QtQuick
import QtTest
import "../../bar/launcher/apps.js" as Apps
import "../../bar/launcher/history.js" as History
import "../../bar/launcher/results.js" as Results

// Desktop entries as items, categories, the stored state and the result list.
TestCase {
    name: "LauncherApps"

    function entry(id, name, categories, extra) {
        var base = {
            id: id, name: name, genericName: "", comment: "", icon: id, noDisplay: false,
            keywords: [], categories: categories, actions: [], execString: "/usr/bin/" + id + " %U"
        }
        for (var key in (extra || {}))
            base[key] = extra[key]
        return base
    }

    function test_the_main_category_comes_from_freedesktop_categories() {
        compare(Apps.categoryOf(["Network", "WebBrowser"]), "internet")
        compare(Apps.categoryOf(["AudioVideo", "Player"]), "multimedia")
        compare(Apps.categoryOf(["Audio"]), "multimedia")
        compare(Apps.categoryOf(["Development", "IDE"]), "development")
        compare(Apps.categoryOf(["System", "TerminalEmulator"]), "system")
        compare(Apps.categoryOf(["Settings", "System"]), "settings")
        compare(Apps.categoryOf(["Game", "Utility"]), "game")
        compare(Apps.categoryOf(["Qt", "KDE"]), "other")
        compare(Apps.categoryOf([]), "other")
        compare(Apps.categoryOf(undefined), "other")
    }

    function test_an_entry_becomes_a_plain_item() {
        var item = Apps.toItem(entry("firefox", "Firefox", ["Network"], {
            genericName: "Web Browser", comment: "Browse the web", keywords: ["internet", "www"]
        }))
        compare(item.id, "firefox")
        compare(item.name, "Firefox")
        compare(item.category, "internet")
        compare(item.exec, "firefox")
        compare(item.group, "apps")
        verify(item.fields.some(function (f) { return f.text === "Web Browser" }))
        verify(item.fields.some(function (f) { return f.text === "internet www" }))
        verify(item.fields.some(function (f) { return f.text === "firefox" }))
    }

    function test_the_exec_name_skips_env_and_arguments() {
        compare(Apps.execName("env FOO=1 /opt/app/bin/thing --flag %U"), "thing")
        compare(Apps.execName("\"/usr/bin/x y\" a"), "x y")
        compare(Apps.execName(""), "")
    }

    function test_hidden_entries_are_left_out() {
        var entries = [entry("a", "A", []), entry("b", "B", [], { noDisplay: true }), entry("c", "C", [])]
        var items = Apps.items(entries, ["c"])
        compare(items.map(function (i) { return i.id }).join(""), "a")
    }

    function test_items_are_sorted_by_name_ignoring_case_and_accents() {
        var items = Apps.items([entry("z", "zeta", []), entry("a", "Álbum", []), entry("b", "beta", [])], [])
        compare(items.map(function (i) { return i.id }).join(""), "abz")
    }

    function test_tabs_list_all_and_only_the_present_categories() {
        var items = Apps.items([
            entry("a", "A", ["Network"]), entry("b", "B", ["Development"]), entry("c", "C", []),
            entry("d", "D", ["Network"])
        ], [])
        var tabs = Apps.tabs(items)
        compare(tabs.map(function (t) { return t.key }).join(","), "all,development,internet,other")
        compare(tabs[0].label, "launcher.cat.all")
        compare(tabs[2].label, "launcher.cat.internet")
    }

    function test_in_category_filters_and_all_keeps_everything() {
        var items = Apps.items([entry("a", "A", ["Network"]), entry("b", "B", ["Game"])], [])
        compare(Apps.inCategory(items, "all").length, 2)
        compare(Apps.inCategory(items, "game").length, 1)
        compare(Apps.inCategory(items, "office").length, 0)
    }

    // --- stored state ------------------------------------------------------

    function test_an_empty_state_has_every_list() {
        var state = History.empty()
        compare(Object.keys(state.history).length, 0)
        compare(state.favourites.length, 0)
        compare(state.hidden.length, 0)
        compare(state.clearedAt, 0)
    }

    function test_parse_is_tolerant() {
        compare(History.parse("").favourites.length, 0)
        compare(History.parse("not json").hidden.length, 0)
        compare(History.parse("[1,2]").favourites.length, 0)
        var partial = History.parse('{"favourites":["a"],"history":5}')
        compare(partial.favourites[0], "a")
        compare(Object.keys(partial.history).length, 0)
    }

    function test_serialize_and_parse_round_trip() {
        var state = History.record(History.empty(), "firefox", 5000)
        state = History.togglePin(state, "kitty")
        state = History.hide(state, "foo")
        var back = History.parse(History.serialize(state))
        compare(back.history.firefox.score, 1)
        compare(back.favourites[0], "kitty")
        compare(back.hidden[0], "foo")
    }

    function test_record_does_not_mutate_the_old_state() {
        var before = History.empty()
        History.record(before, "a", 1)
        compare(Object.keys(before.history).length, 0)
    }

    function test_recording_twice_counts_twice() {
        var state = History.record(History.record(History.empty(), "a", 100), "a", 100)
        compare(state.history.a.score, 2)
    }

    function test_history_is_capped_keeping_the_most_used() {
        var state = History.empty()
        for (var i = 0; i < 260; i++)
            state = History.record(state, "app" + i, 1000)
        state = History.record(state, "app3", 1000)
        state = History.record(state, "app3", 1000)
        verify(Object.keys(state.history).length <= 200)
        verify(state.history.app3 !== undefined)
    }

    function test_pin_toggles() {
        var state = History.togglePin(History.empty(), "a")
        compare(state.favourites.length, 1)
        compare(History.togglePin(state, "a").favourites.length, 0)
        verify(History.isPinned(state, "a"))
        verify(!History.isPinned(state, "b"))
    }

    function test_hiding_unpins() {
        var state = History.hide(History.togglePin(History.empty(), "a"), "a")
        compare(state.favourites.length, 0)
        compare(state.hidden[0], "a")
    }

    function test_clearing_drops_usage_but_keeps_favourites_and_hidden() {
        var state = History.togglePin(History.record(History.empty(), "a", 10), "b")
        state = History.hide(state, "c")
        var cleared = History.clear(state, 500)
        compare(Object.keys(cleared.history).length, 0)
        compare(cleared.favourites[0], "b")
        compare(cleared.hidden[0], "c")
        compare(cleared.clearedAt, 500)
    }

    function test_a_clear_request_runs_only_once() {
        var state = History.clear(History.empty(), 500)
        state = History.record(state, "a", 600)
        var again = History.applyRequest(state, "500")
        compare(Object.keys(again.history).length, 1)
        var newer = History.applyRequest(state, "700")
        compare(Object.keys(newer.history).length, 0)
        compare(History.applyRequest(state, "").clearedAt, 500)
        compare(History.applyRequest(state, "junk").clearedAt, 500)
    }

    function test_a_hidden_request_brings_hidden_apps_back_and_keeps_usage() {
        var state = History.hide(History.record(History.empty(), "a", 10), "b")
        var shown = History.applyRequest(state, "900:hidden")
        compare(shown.hidden.length, 0)
        compare(Object.keys(shown.history).length, 1)
        compare(shown.clearedAt, 900)
    }

    // --- results -----------------------------------------------------------

    function result(group, id) {
        return { id: id, group: group, title: id }
    }

    function test_sections_group_results_in_order_with_headers() {
        var list = [result("web", "w"), result("apps", "a1"), result("actions", "x"), result("apps", "a2")]
        var shown = Results.sections(list, Results.GROUPS, {})
        compare(shown.rows.map(function (r) { return r.header ? "#" + r.group : r.result.id }).join(","),
                "#apps,a1,a2,#actions,x,#web,w")
        compare(shown.list.map(function (r) { return r.id }).join(","), "a1,a2,x,w")
        compare(shown.rows[1].index, 0)
        compare(shown.rows[2].index, 1)
    }

    function test_sections_cap_each_group() {
        var list = [result("apps", "a1"), result("apps", "a2"), result("apps", "a3")]
        var shown = Results.sections(list, Results.GROUPS, { apps: 2 })
        compare(shown.list.length, 2)
    }

    function test_the_order_can_put_a_group_first() {
        var list = [result("apps", "a"), result("web", "w")]
        var shown = Results.sections(list, ["web", "apps"], {})
        compare(shown.list[0].id, "w")
    }

    function test_a_single_group_has_no_header() {
        var shown = Results.sections([result("files", "f")], Results.GROUPS, {}, true)
        compare(shown.rows.length, 1)
        compare(shown.rows[0].index, 0)
    }

    function test_clamp_keeps_the_selection_in_range() {
        compare(Results.clamp(-3, 4), 0)
        compare(Results.clamp(9, 4), 3)
        compare(Results.clamp(2, 0), 0)
    }

    function test_list_step_wraps() {
        compare(Results.step(0, 4, -1), 3)
        compare(Results.step(3, 4, 1), 0)
        compare(Results.step(1, 4, 1), 2)
        compare(Results.step(0, 0, 1), 0)
    }

    // Sections of 3, 2 and 8 tiles in a grid of 4 columns.
    function test_grid_moves_by_rows_across_sections() {
        var lengths = [3, 2, 8]
        compare(Results.gridMove(lengths, 4, 0, "down"), 3)   // first of the next section
        compare(Results.gridMove(lengths, 4, 2, "down"), 4)   // column clamped to the row's end
        compare(Results.gridMove(lengths, 4, 3, "down"), 5)   // 2nd section, col 0 -> 3rd section row 0
        compare(Results.gridMove(lengths, 4, 6, "down"), 10)  // inside the third section: next row, same column
        compare(Results.gridMove(lengths, 4, 9, "up"), 5)
        compare(Results.gridMove(lengths, 4, 5, "up"), 3)
        compare(Results.gridMove(lengths, 4, 3, "up"), 0)
        compare(Results.gridMove(lengths, 4, 1, "up"), 1)     // already at the top: stays
        compare(Results.gridMove(lengths, 4, 12, "down"), 12) // already at the bottom: stays
    }

    function test_grid_left_and_right_walk_every_tile() {
        var lengths = [3, 2, 8]
        compare(Results.gridMove(lengths, 4, 0, "right"), 1)
        compare(Results.gridMove(lengths, 4, 2, "right"), 3)
        compare(Results.gridMove(lengths, 4, 12, "right"), 12)
        compare(Results.gridMove(lengths, 4, 3, "left"), 2)
        compare(Results.gridMove(lengths, 4, 0, "left"), 0)
    }

    function test_empty_sections_are_skipped() {
        compare(Results.gridMove([0, 2, 5], 4, 0, "down"), 2)
        compare(Results.gridMove([0, 0, 0], 4, 0, "down"), 0)
    }

    function test_the_section_and_position_of_a_flat_index() {
        var at = Results.locate([3, 2, 8], 4, 6)
        compare(at.section, 2)
        compare(at.row, 0)
        compare(at.column, 1)
    }
}
