import QtQuick
import QtTest
import "../../bar/wallpapermonitors.js" as Wallpaper

// The per-monitor wallpaper document: tolerant parsing, one patch at a time.
TestCase {
    name: "WallpaperMonitors"

    function test_parse_is_tolerant() {
        compare(Wallpaper.stringify(Wallpaper.parse("")), "{}")
        compare(Wallpaper.stringify(Wallpaper.parse("not json")), "{}")
        compare(Wallpaper.stringify(Wallpaper.parse("[]")), "{}")
        compare(Wallpaper.stringify(Wallpaper.parse('{"DP-1":{"wallpaper":"/w/a.png"}}')), '{"DP-1":{"wallpaper":"/w/a.png"}}')
    }

    function test_an_output_without_an_entry_follows_the_global_choice() {
        compare(Wallpaper.of("", "DP-1"), ({ wallpaper: "" }))
        compare(Wallpaper.of('{"DP-1": 3}', "DP-1"), ({ wallpaper: "" }))
    }

    function test_the_picture_is_readable() {
        var text = '{"DP-1":{"wallpaper":"/w/a.png"}}'
        compare(Wallpaper.of(text, "DP-1").wallpaper, "/w/a.png")
        compare(Wallpaper.of(text, "HDMI-A-1").wallpaper, "")
    }

    function test_update_keeps_the_other_outputs() {
        var first = Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" })
        var second = Wallpaper.update(first, "HDMI-A-1", { wallpaper: "/w/b.png" })
        compare(Wallpaper.of(second, "DP-1").wallpaper, "/w/a.png")
        compare(Wallpaper.of(second, "HDMI-A-1").wallpaper, "/w/b.png")
    }

    function test_update_is_null_when_nothing_changes() {
        var text = Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" })
        compare(Wallpaper.update(text, "DP-1", { wallpaper: "/w/a.png" }), null)
        compare(Wallpaper.update("", "DP-1", { wallpaper: "" }), null)
    }

    // A document from before the effect became global still parses; the next
    // patch drops the leftover key.
    function test_a_leftover_effect_is_dropped_on_the_next_patch() {
        var legacy = '{"DP-1":{"wallpaper":"/w/a.png","effect":"blur"}}'
        compare(Wallpaper.of(legacy, "DP-1").wallpaper, "/w/a.png")
        var text = Wallpaper.update(legacy, "DP-1", { wallpaper: "/w/b.png" })
        compare(Wallpaper.stringify(Wallpaper.parse(text)), '{"DP-1":{"wallpaper":"/w/b.png"}}')
    }

    function test_clearing_the_picture_drops_the_entry() {
        var text = Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" })
        var cleared = Wallpaper.update(text, "DP-1", { wallpaper: "" })
        compare(Wallpaper.stringify(Wallpaper.parse(cleared)), "{}")
    }

    function test_remove_drops_only_that_output() {
        var text = Wallpaper.update(Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" }),
                                    "HDMI-A-1", { wallpaper: "/w/b.png" })
        var only = Wallpaper.parse(Wallpaper.remove(text, "DP-1"))
        compare(only["DP-1"], undefined)
        compare(only["HDMI-A-1"].wallpaper, "/w/b.png")
        compare(Wallpaper.remove(text, "eDP-1"), null)
    }
}
