import QtQuick
import QtTest
import "../../bar/prefs.js" as Prefs

// The bar merges one INI file per area into the preferences it reads.
TestCase {
    name: "BarPrefs"

    function test_the_map_lists_each_file_once_in_order() {
        compare(Prefs.files("# note\n\nbar barSize\nbar barEdge\nwallpaper wallpaper\n"),
                ["bar", "wallpaper"])
    }

    function test_parse_reads_compact_and_spaced_values_in_any_section() {
        var out = Prefs.parse("[bar]\nbarSize=40\nbarEdge = top\n; note\n[other]\nempty=\n")
        compare(out, { barSize: "40", barEdge: "top", empty: "" })
    }

    function test_a_value_may_contain_equals_signs() {
        compare(Prefs.parse("bangs=g*Google*https://x/?q=%s\n").bangs, "g*Google*https://x/?q=%s")
    }

    function test_a_value_quoted_by_the_settings_window_is_read_whole() {
        var out = Prefs.parse('[misc]\nvpnSettings="{\\"a\\":[1,2],\\"b\\":\\"x\\\\y\\"}"\nquickNotes=["uno","dos"]\nplain=a"b"\n')
        compare(out.vpnSettings, '{"a":[1,2],"b":"x\\y"}')
        compare(out.quickNotes, '["uno","dos"]')
        compare(out.plain, 'a"b"')
    }

    function test_merge_joins_the_files_and_skips_missing_ones() {
        var parts = { bar: { barSize: "40" }, appearance: { radius: "9" } }
        compare(Prefs.merge(parts, ["appearance", "bar", "wallpaper"]), { radius: "9", barSize: "40" })
    }
}
