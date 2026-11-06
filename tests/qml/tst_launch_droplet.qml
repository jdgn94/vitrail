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

    function test_the_mapping_window_places_the_final_rect_before_fading() {
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

        request = Droplet.arrive(request, local, 1500)
        compare(request.phase, "placing")
        compare(request.target.x, 0)
        compare(request.target.width, 960)

        request = Droplet.fade(request, 1800)
        compare(request.phase, "fading")
        compare(request.target.width, 960)
    }

    function test_an_app_reserves_its_last_known_rect() {
        var rects = {
            "0x1": { address: "0x1", class: "Google-chrome",
                     rect: { x: 981, y: 16, width: 923, height: 1048 } },
            "0x2": { address: "0x2", class: "kitty",
                     rect: { x: 0, y: 0, width: 400, height: 300 } }
        }
        var last = Droplet.lastRect(app({ id: "google-chrome.desktop" }), rects)
        compare(last.x, 981)
        compare(last.y, 16)
        compare(last.width, 923)
        compare(last.height, 1048)
        compare(Droplet.lastRect(app({ id: "spotify.desktop" }), rects), null)
        compare(Droplet.lastRect(app(), {}), null)
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

    function test_a_keyboard_launch_starts_at_the_pointer() {
        var pointer = { x: 2000, y: 400 }
        var origin = Droplet.pointerOrigin(pointer, screen)
        compare(origin.x, 80)
        compare(origin.y, 400)
        compare(origin.width, 2)
        compare(origin.height, 2)
        var request = Droplet.request(app(), origin, space, 1000, 4000, "DP-1")
        compare(request.origin.x, 80)
        compare(request.origin.y, 400)
    }

    function test_the_pointer_picks_the_monitor_that_holds_it() {
        var screens = [screen, { x: 0, y: 0, width: 1920, height: 1080 }]
        compare(Droplet.screenFor({ x: 2500, y: 500 }, screens).x, 1920)
        compare(Droplet.screenFor({ x: 500, y: 500 }, screens).x, 0)
        compare(Droplet.screenFor({ x: -10, y: 500 }, screens), null)
    }

    function test_a_closing_window_puffs_from_its_last_rect() {
        var last = { x: 200, y: 100, width: 800, height: 600 }
        var close = Droplet.closing(last, 2000, "DP-1", 1.12)
        compare(close.phase, "closing")
        compare(close.screen, "DP-1")
        compare(close.origin.x, 200)
        compare(close.origin.width, 800)
        compare(close.target.x, 152)
        compare(close.target.y, 64)
        compare(close.target.width, 896)
        compare(close.target.height, 672)
        verify(!Droplet.closingDone(close, 2199, 250))
        verify(Droplet.closingDone(close, 2250, 250))
    }

    function test_the_live_map_reports_open_and_closed_windows() {
        var first = Droplet.sync({}, [windowOf("0x1", "kitty", 0, 0, 400, 300)])
        compare(first.added.length, 1)
        compare(first.closed.length, 0)
        compare(first.rects["0x1"].rect.width, 400)

        var second = Droplet.sync(first.rects,
                                  [windowOf("0x2", "firefox", 100, 100, 800, 600)])
        compare(second.added.length, 1)
        compare(second.added[0].address, "0x2")
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
        var first = Droplet.closing({ x: 0, y: 0, width: 400, height: 300 }, 1000, "DP-1", 1.12)
        var second = Droplet.closing({ x: 500, y: 100, width: 300, height: 200 }, 1010, "DP-1", 1.12)
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

}
