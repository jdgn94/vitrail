import QtQuick
import QtTest
import "../../bar/droplet/droplet.js" as Droplet

// The launch droplet's state machine: it starts at the icon, holds the space
// the window will take, follows the window when it maps, and gives up after
// the timeout. Focusing an open app never asks for one.
TestCase {
    name: "LaunchDroplet"

    readonly property var screen: ({ x: 1920, y: 0, width: 1920, height: 1080 })
    readonly property var fallback: ({ x: 480, y: 270, width: 960, height: 540 })

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

    function test_a_launch_starts_at_the_icon_and_holds_the_fallback_space() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
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
        compare(Droplet.request(app({ open: true, address: "0xabc" }), icon(), fallback, 1000, 4000, "DP-1"), null)
        verify(Droplet.request(app({ open: false }), icon(), fallback, 1000, 4000, "DP-1") !== null)
    }

    function test_the_mapping_window_replaces_the_fallback() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        var found = Droplet.arrival(request,
                                   [windowOf("0xabc", "firefox", 2200, 300, 900, 600)],
                                   ["0x111"], screen)
        compare(found.address, "0xabc")
        compare(found.rect.x, 2200)
        compare(found.rect.width, 900)

        var local = Droplet.local(found.rect, screen)
        compare(local.x, 280)
        compare(local.y, 300)

        request = Droplet.arrive(request, local, 1500)
        compare(request.phase, "fading")
        compare(request.target.x, 280)
        compare(request.target.width, 900)
    }

    function test_an_old_window_is_not_mistaken_for_the_new_one() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        compare(Droplet.arrival(request, [windowOf("0x111", "firefox", 2200, 300, 900, 600)],
                                ["0x111"], screen), null)
    }

    function test_a_window_on_another_screen_is_not_taken() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        compare(Droplet.arrival(request, [windowOf("0xabc", "firefox", 100, 300, 900, 600)],
                                [], screen), null)
    }

    function test_a_matching_class_wins_over_the_first_new_window() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        var found = Droplet.arrival(request, [
            windowOf("0x1", "kitty", 2000, 100, 400, 300),
            windowOf("0x2", "firefox", 2000, 500, 800, 500)
        ], [], screen)
        compare(found.address, "0x2")
    }

    function test_the_timeout_fades_when_no_window_appears() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        verify(!Droplet.expired(request, 4999))
        verify(Droplet.expired(request, 5000))
        var faded = Droplet.timeout(request, 5000)
        compare(faded.phase, "fading")
        compare(faded.target.x, 480)
    }

    function test_ending_clears_the_drop() {
        var request = Droplet.request(app(), icon(), fallback, 1000, 4000, "DP-1")
        compare(Droplet.finish(request), null)
        verify(!Droplet.active(null))
    }

    function test_the_fallback_is_centred_on_the_screen() {
        var centred = Droplet.fallback(1920, 1080, 0.5, 0.5)
        compare(centred.x, 480)
        compare(centred.y, 270)
        compare(centred.width, 960)
        compare(centred.height, 540)
    }
}
