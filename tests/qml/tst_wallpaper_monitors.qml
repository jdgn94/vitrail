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
        compare(Wallpaper.stringify(Wallpaper.parse('{"DP-1":{"effect":"blur"}}')), '{"DP-1":{"effect":"blur"}}')
    }

    function test_an_output_without_an_entry_follows_the_global_choice() {
        compare(Wallpaper.of("", "DP-1"), ({ wallpaper: "", effect: "" }))
        compare(Wallpaper.of('{"DP-1": 3}', "DP-1"), ({ wallpaper: "", effect: "" }))
    }

    function test_both_fields_are_readable() {
        var text = '{"DP-1":{"wallpaper":"/w/a.png","effect":"sepia"}}'
        compare(Wallpaper.of(text, "DP-1").wallpaper, "/w/a.png")
        compare(Wallpaper.of(text, "DP-1").effect, "sepia")
        compare(Wallpaper.of(text, "HDMI-A-1").wallpaper, "")
    }

    function test_update_sets_one_field_and_keeps_the_other() {
        var first = Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" })
        var both = Wallpaper.update(first, "DP-1", { effect: "blur" })
        compare(Wallpaper.of(both, "DP-1"), ({ wallpaper: "/w/a.png", effect: "blur" }))
    }

    function test_update_keeps_the_other_outputs() {
        var first = Wallpaper.update("", "DP-1", { effect: "blur" })
        var second = Wallpaper.update(first, "HDMI-A-1", { wallpaper: "/w/b.png" })
        compare(Wallpaper.of(second, "DP-1").effect, "blur")
        compare(Wallpaper.of(second, "HDMI-A-1").wallpaper, "/w/b.png")
    }

    function test_update_is_null_when_nothing_changes() {
        var text = Wallpaper.update("", "DP-1", { effect: "blur" })
        compare(Wallpaper.update(text, "DP-1", { effect: "blur" }), null)
        compare(Wallpaper.update("", "DP-1", { effect: "" }), null)
    }

    function test_clearing_both_fields_drops_the_entry() {
        var text = Wallpaper.update("", "DP-1", { wallpaper: "/w/a.png" })
        var cleared = Wallpaper.update(text, "DP-1", { wallpaper: "" })
        compare(Wallpaper.stringify(Wallpaper.parse(cleared)), "{}")
    }

    function test_remove_drops_only_that_output() {
        var text = Wallpaper.update(Wallpaper.update("", "DP-1", { effect: "blur" }),
                                    "HDMI-A-1", { effect: "sepia" })
        var only = Wallpaper.parse(Wallpaper.remove(text, "DP-1"))
        compare(only["DP-1"], undefined)
        compare(only["HDMI-A-1"].effect, "sepia")
        compare(Wallpaper.remove(text, "eDP-1"), null)
    }
}
