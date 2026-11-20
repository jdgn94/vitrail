import QtQuick
import QtTest
import "../../bar/droplet/droplet.js" as Droplet

// The launch droplet's state machine: it starts at the icon, holds the space
// the window will take, follows the window when it maps, and gives up after
// the timeout. Focusing an open app never asks for one.
TestCase {
    name: "LaunchDroplet"

    readonly property var screen: ({ x: 1920, y: 0, width: 1920, height: 1080 })
    readonly property var space: ({ x: 480, y: 270, width: 960, height: 540 })

    function app(extra) {
        var base = { id: "firefox.desktop", name: "Firefox", icon: "firefox" }
        for (var key in (extra || {}))
            base[key] = extra[key]
        return base
    }

    function icon() {
        return { x: 40, y: 980, width: 40, height: 40 }
    }

    function windowOf(address, klass, x, y, width, height) {
        return {
            address: address,
            title: klass,
            lastIpcObject: { "class": klass, at: [x, y], size: [width, height] }
        }
    }

    function test_a_launch_starts_at_the_icon_and_holds_the_requested_space() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        compare(request.phase, "hold")
        compare(request.origin.x, 40)
        compare(request.origin.width, 40)
        compare(request.target.x, 480)
        compare(request.target.width, 960)
        compare(request.screen, "DP-1")
        compare(request.deadline, 5000)
        verify(Droplet.active(request))
        verify(!Droplet.expired(request, 4999))
    }

    function test_focusing_an_open_app_never_starts_a_drop() {
        compare(Droplet.request(app({ open: true, address: "0xabc" }), icon(), space, 1000, 4000, "DP-1"), null)
        verify(Droplet.request(app({ open: false }), icon(), space, 1000, 4000, "DP-1") !== null)
    }

    function test_the_mapping_window_settles_and_the_drop_hands_over_by_fading() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        var floating = windowOf("0xabc", "firefox", 2200, 300, 900, 600)
        var found = Droplet.arrival(request, [floating], ["0x111"], screen)
        compare(found.address, "0xabc")

        request = Droplet.watch(request, found, 1000, 250)
        compare(request.phase, "settling")
        // The drop keeps the space while Hyprland is still placing it.
        compare(request.target.x, space.x)
        compare(request.pending.x, 2200)

        var tiled = [windowOf("0xabc", "firefox", 1920, 0, 960, 1080)]
        request = Droplet.settle(request, tiled, 1060)
        compare(request.phase, "settling")
        compare(request.pending.x, 1920)

        request = Droplet.settle(request, tiled, 1120)
        compare(request.phase, "settled")
        compare(request.final.x, 1920)
        compare(request.final.width, 960)

        var local = Droplet.local(request.final, screen)
        compare(local.x, 0)
        compare(local.y, 0)

        // The window animates itself: the drop only fades, over the space it held.
        request = Droplet.fade(request, 1800)
        compare(request.phase, "fading")
        compare(request.target.x, space.x)
        compare(request.target.width, space.width)
    }

    function test_a_window_on_the_predicted_slot_is_near_and_a_far_one_is_not() {
        var slot = { x: 16, y: 46, width: 1258, height: 1316 }
        verify(Droplet.near({ x: 18, y: 44, width: 1260, height: 1314 }, slot, 24))
        verify(Droplet.near(slot, slot, 0))
        verify(!Droplet.near({ x: 1286, y: 46, width: 1258, height: 1316 }, slot, 24))
        verify(!Droplet.near({ x: 16, y: 46, width: 900, height: 600 }, slot, 24))
    }

    // The live session: 2560x1440 at 0,0, reserved [6, 36, 6, 68], gaps_in 4,
    // gaps_out 8, border 2, dwindle.
    readonly property var live: ({
        layout: "dwindle", gapsIn: 4, gapsOut: 8, border: 2, splitWidth: 1, forceSplit: 0,
        area: { x: 6, y: 36, width: 2548, height: 1336 }
    })
    readonly property var lone: ({ x: 16, y: 46, width: 2528, height: 1316 })

    function plan(extra) {
        var input = {}
        for (var key in live)
            input[key] = live[key]
        for (var change in extra)
            input[change] = extra[change]
        return input
    }

    function expectRect(box, x, y, width, height) {
        verify(box !== null)
        compare(box.x, x)
        compare(box.y, y)
        compare(box.width, width)
        compare(box.height, height)
    }

    function test_an_empty_workspace_gives_the_whole_area_inside_the_gaps() {
        expectRect(Droplet.predict(plan({ windows: [], cursor: null })), 16, 46, 2528, 1316)
    }

    function test_a_lone_window_splits_side_by_side_by_the_cursor_half() {
        var windows = [lone]
        expectRect(Droplet.predict(plan({ windows: windows, cursor: { x: 718, y: 1240 } })),
                   16, 46, 1258, 1316)
        expectRect(Droplet.predict(plan({ windows: windows, cursor: { x: 2000, y: 700 } })),
                   1286, 46, 1258, 1316)
        // No pointer: the newcomer goes second.
        expectRect(Droplet.predict(plan({ windows: windows, cursor: null })),
                   1286, 46, 1258, 1316)
    }

    function test_a_tall_node_splits_top_and_bottom() {
        var tall = { x: 1286, y: 46, width: 1258, height: 1316 }
        var windows = [{ x: 16, y: 46, width: 1258, height: 1316 }, tall]
        var top = Droplet.predict(plan({ windows: windows, cursor: { x: 1500, y: 100 } }))
        expectRect(top, 1286, 46, 1258, 652)
        var bottom = Droplet.predict(plan({ windows: windows, cursor: { x: 1500, y: 1300 } }))
        expectRect(bottom, 1286, 710, 1258, 652)
    }

    function test_without_a_window_under_the_cursor_the_focused_one_is_split() {
        var left = { x: 16, y: 46, width: 1258, height: 1316, address: "0xa" }
        var right = { x: 1286, y: 46, width: 1258, height: 1316, address: "0xb" }
        var outside = { x: 5000, y: 5000 }
        expectRect(Droplet.predict(plan({ windows: [left, right], focused: "b", cursor: outside })),
                   1286, 710, 1258, 652)
        expectRect(Droplet.predict(plan({ windows: [left, right], focused: left, cursor: null })),
                   16, 710, 1258, 652)
        // Nothing focused: the first window.
        expectRect(Droplet.predict(plan({ windows: [left, right], cursor: null })),
                   16, 710, 1258, 652)
    }

    function test_force_split_decides_the_side_over_the_cursor() {
        var windows = [lone]
        expectRect(Droplet.predict(plan({ windows: windows, forceSplit: 1,
                                          cursor: { x: 2000, y: 700 } })),
                   16, 46, 1258, 1316)
        expectRect(Droplet.predict(plan({ windows: windows, forceSplit: 2,
                                          cursor: { x: 718, y: 1240 } })),
                   1286, 46, 1258, 1316)
    }

    function test_another_layout_or_a_fullscreen_window_cannot_be_foretold() {
        compare(Droplet.predict(plan({ layout: "master", windows: [], cursor: null })), null)
        compare(Droplet.predict(plan({ windows: [lone], cursor: null,
                                       layout: "scrolling" })), null)
        var full = { x: 0, y: 0, width: 2560, height: 1440, fullscreen: true }
        compare(Droplet.predict(plan({ windows: [full], cursor: null })), null)
        compare(Droplet.predict(null), null)
    }

    function test_hyprland_options_are_read_from_the_batch_answer() {
        var output = '{"option": "general:gaps_in", "css": "4 4 4 4", "set": true }\n\n\n'
                     + '{"option": "general:gaps_out", "css": "8 8 8 8", "set": true }\n\n\n'
                     + '{"option": "general:border_size", "int": 2, "set": true }\n\n\n'
                     + '{"option": "general:layout", "str": "dwindle", "set": true }\n\n\n'
                     + '{"option": "dwindle:force_split", "int": 0, "set": false }\n\n\n'
                     + '{"option": "dwindle:split_width_multiplier", "float": 1.500000, "set": false }\n\n'
        var options = Droplet.parseOptions(output)
        compare(options.gapsIn, 4)
        compare(options.gapsOut, 8)
        compare(options.border, 2)
        compare(options.layout, "dwindle")
        compare(options.forceSplit, 0)
        compare(options.splitWidth, 1.5)
        compare(Droplet.parseOptions("garbage\nnot json"), null)
        compare(Droplet.parseOptions(""), null)
    }

    function test_the_pointer_is_read_from_the_json_answer() {
        var point = Droplet.parseCursor('{\n    "x": 718,\n    "y": 1240\n}\n')
        compare(point.x, 718)
        compare(point.y, 1240)
        compare(Droplet.parseCursor("718, 1240"), null)
        compare(Droplet.parseCursor(""), null)
    }

    function workspaceWindow(address, workspace, x, y, width, height, extra) {
        var top = windowOf(address, "kitty", x, y, width, height)
        top.lastIpcObject.workspace = { id: workspace }
        top.lastIpcObject.mapped = true
        for (var key in (extra || {}))
            top.lastIpcObject[key] = extra[key]
        return top
    }

    function monitor() {
        return {
            lastIpcObject: { x: 0, y: 0, width: 2560, height: 1440, scale: 1,
                             reserved: [6, 36, 6, 68], activeWorkspace: { id: 3 } },
            activeWorkspace: { lastIpcObject: { lastwindow: "0xb" } }
        }
    }

    function test_the_forecast_uses_the_monitors_active_workspace_windows() {
        var options = { layout: "dwindle", gapsIn: 4, gapsOut: 8, border: 2,
                        splitWidth: 1, forceSplit: 0 }
        var cursor = { x: 718, y: 1240 }
        expectRect(Droplet.forecast(options, [], monitor(), cursor), 16, 46, 2528, 1316)
        // Other workspaces, floating and unmapped windows do not take space.
        var tops = [
            workspaceWindow("0xa", 2, 16, 46, 1000, 1000),
            workspaceWindow("0xc", 3, 100, 100, 300, 300, { floating: true }),
            workspaceWindow("0xd", 3, 100, 100, 300, 300, { mapped: false }),
            workspaceWindow("0xb", 3, 16, 46, 2528, 1316)
        ]
        expectRect(Droplet.forecast(options, tops, monitor(), cursor), 16, 46, 1258, 1316)
        tops.push(workspaceWindow("0xe", 3, 0, 0, 2560, 1440, { fullscreen: 2 }))
        compare(Droplet.forecast(options, tops, monitor(), cursor), null)
        compare(Droplet.forecast(null, tops, monitor(), cursor), null)
        compare(Droplet.forecast(options, tops, null, cursor), null)
    }

    function test_the_settle_window_takes_the_last_rect_while_it_moves() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        var found = Droplet.arrival(request,
                                   [windowOf("0xabc", "firefox", 2200, 300, 900, 600)],
                                   [], screen)
        request = Droplet.watch(request, found, 1000, 250)
        request = Droplet.settle(request,
                                 [windowOf("0xabc", "firefox", 1920, 0, 960, 1080)],
                                 1100)
        compare(request.phase, "settling")
        request = Droplet.settle(request,
                                 [windowOf("0xabc", "firefox", 1920, 0, 1280, 1080)],
                                 1250)
        compare(request.phase, "settled")
        compare(request.final.width, 1280)
    }

    function test_an_old_window_is_not_mistaken_for_the_new_one() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        compare(Droplet.arrival(request, [windowOf("0x111", "firefox", 2200, 300, 900, 600)],
                                ["0x111"], screen), null)
    }

    function test_a_window_on_another_screen_is_not_taken() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        compare(Droplet.arrival(request, [windowOf("0xabc", "firefox", 100, 300, 900, 600)],
                                [], screen), null)
    }

    function test_a_matching_class_wins_over_the_first_new_window() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        var found = Droplet.arrival(request, [
            windowOf("0x1", "kitty", 2000, 100, 400, 300),
            windowOf("0x2", "firefox", 2000, 500, 800, 500)
        ], [], screen)
        compare(found.address, "0x2")
    }

    function test_the_timeout_fades_when_no_window_appears() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        verify(!Droplet.expired(request, 4999))
        verify(Droplet.expired(request, 5000))
        var faded = Droplet.timeout(request, 5000)
        compare(faded.phase, "fading")
        compare(faded.target.x, 480)
    }

    function test_ending_clears_the_drop() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        compare(Droplet.finish(request), null)
        verify(!Droplet.active(null))
    }

    function test_the_pointer_picks_the_monitor_that_holds_it() {
        var screens = [screen, { x: 0, y: 0, width: 1920, height: 1080 }]
        compare(Droplet.screenFor({ x: 2500, y: 500 }, screens).x, 1920)
        compare(Droplet.screenFor({ x: 500, y: 500 }, screens).x, 0)
        compare(Droplet.screenFor({ x: -10, y: 500 }, screens), null)
    }

    function test_a_closing_window_bursts_from_its_last_rect() {
        var last = { x: 200, y: 100, width: 800, height: 600 }
        var close = Droplet.closing(last, 2000, "DP-1")
        compare(close.phase, "closing")
        compare(close.screen, "DP-1")
        compare(close.origin.x, 200)
        compare(close.origin.width, 800)
        compare(close.target.x, 200)
        compare(close.target.width, 800)
        verify(!Droplet.closingDone(close, 2199, 250))
        verify(Droplet.closingDone(close, 2250, 250))
    }

    function test_the_live_map_reports_closed_windows() {
        var first = Droplet.sync({}, [windowOf("0x1", "kitty", 0, 0, 400, 300)])
        compare(first.closed.length, 0)
        compare(first.rects["0x1"].rect.width, 400)

        var second = Droplet.sync(first.rects,
                                  [windowOf("0x2", "firefox", 100, 100, 800, 600)])
        compare(second.closed.length, 1)
        compare(second.closed[0].address, "0x1")
        compare(second.closed[0].rect.width, 400)
    }

    function test_vitrail_windows_are_not_closed_with_a_drop() {
        verify(Droplet.own({ class: "vitrail-settings" }))
        verify(Droplet.own({ class: "vitrail" }))
        verify(!Droplet.own({ class: "firefox" }))
        verify(!Droplet.own({}))
    }

    function test_back_to_back_closes_wait_in_fifo_order() {
        var first = Droplet.closing({ x: 0, y: 0, width: 400, height: 300 }, 1000, "DP-1")
        var second = Droplet.closing({ x: 500, y: 100, width: 300, height: 200 }, 1010, "DP-1")
        var queue = Droplet.enqueueClose([], first)
        queue = Droplet.enqueueClose(queue, second)
        compare(queue.length, 2)
        var next = Droplet.nextClose(queue)
        compare(next.request, first)
        compare(next.queue.length, 1)
        next = Droplet.nextClose(next.queue)
        compare(next.request, second)
        compare(next.queue.length, 0)
        compare(Droplet.nextClose(next.queue).request, null)
    }

    function test_the_desktop_entry_runs_only_after_the_opening_animation() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        var calls = []
        var entry = { execute: function () { calls.push(Date.now()) } }
        request = Droplet.schedule(request, entry, 1260)
        compare(request.launchAt, 1260)
        verify(!request.launched)
        request = Droplet.launch(request, 1259)
        compare(calls.length, 0)
        verify(!request.launched)
        request = Droplet.launch(request, 1260)
        compare(calls.length, 1)
        verify(request.launched)
        request = Droplet.launch(request, 1400)
        compare(calls.length, 1)
    }

    function test_a_launch_without_an_entry_keeps_the_existing_behavior() {
        var request = Droplet.request(app(), icon(), space, 1000, 4000, "DP-1")
        request = Droplet.schedule(request, null, 1260)
        verify(request.launched)
        compare(Droplet.launch(request, 1000), request)
    }

}
